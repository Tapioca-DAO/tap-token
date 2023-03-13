import { Contract } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TContract } from 'tapioca-sdk/dist/shared';
import { Multicall3 } from 'tapioca-sdk/dist/typechain/utils/MultiCall';
import { v4 as uuidv4 } from 'uuid';
import { TapiocaDeployer } from '../typechain';

interface IDependentOn {
    deploymentName: string;
    argPosition: number;
}

interface IDeploymentQueue {
    deploymentName: string;
    contract: Contract;
    args: unknown[];
    dependsOn?: IDependentOn[];
}

interface TDeploymentVMContract extends TContract {
    meta: { args: unknown[]; salt: string; create2: true };
}

/**
 * Class to deploy contracts using the TapiocaDeployer & Multicall3 to aggregate deployments in a single transaction.
 * @param hre HardhatRuntimeEnvironment instance of Hardhat.
 * @param options Options to use.
 * @param options.tag Tag to use for the deployment. If not provided, 'default' will be used (Per SDK).
 * @param options.multicall Multicall3 instance to use for the deployment.
 *
 */
export class DeployerVM {
    #tapiocaDeployer?: TapiocaDeployer;

    multicall: Multicall3;
    hre: HardhatRuntimeEnvironment;
    tag?: string;

    /**
     * Queue of contracts to deploy
     * Runtime bound, equal to [] when creating a new instance of this class or after flushing the runtime.
     */
    private deploymentQueue: IDeploymentQueue[] = [];

    /**
     * Queue of contract to build. Used to build the bytecode for the TapiocaDeployer.
     * Runtime bound, equal to [] when creating a new instance of this class or after flushing the runtime.
     * This is a private queue used to build the calls to the multicall contract
     */
    private buildQueue: (IDeploymentQueue & {
        deterministicAddress: string;
        creationCode: string;
        salt: string;
    })[] = [];

    /**
     * Flag to check if the deployment queue has been executed
     */
    private executed = false;

    constructor(
        hre: HardhatRuntimeEnvironment,
        options: { multicall: Multicall3; tag?: string },
    ) {
        this.hre = hre;
        this.multicall = options.multicall;
        this.tag = options.tag;
    }

    // ***********
    // Getter
    // ***********

    /**
     * Returns the current state of deployment queue
     */
    getQueue() {
        return this.deploymentQueue;
    }

    /**
     * Returns the current state of the build queue
     */
    getBuildQueue() {
        return this.buildQueue;
    }

    /**
     * Return a list of deployed contracts
     */
    list(): TDeploymentVMContract[] {
        return this.buildQueue.map((contract) => ({
            name: contract.deploymentName,
            address: contract.deterministicAddress,
            meta: {
                args: contract.args,
                salt: contract.salt,
                create2: true,
            },
        }));
    }

    // ***********
    // Setter
    // ***********

    /**
     * Add a contract to the deployment queue
     */
    add<T extends Contract>(
        contract: IDeploymentQueue & {
            contract: T;
            args: Parameters<T['deploy']>;
        },
    ) {
        // Validate contract dependencies
        contract.dependsOn?.forEach((dependency) => {
            if (dependency.argPosition < contract.args.length) {
                throw new Error(
                    `[-] Dependency for ${contract.deploymentName} argPosition is out of bounds`,
                );
            }
        });

        console.log(
            '[+] Adding contract to deployment queue: ',
            contract.deploymentName,
        );
        this.deploymentQueue.push(contract);
        return this;
    }

    /**
     * Execute the current build queue and deploy the contracts, using Multicall3 to aggregate the calls.
     */
    async execute() {
        console.log('[+] Executing deployment queue...');

        const calls = await this.getBuildCalls();

        await (await this.multicall.aggregate3(calls)).wait();
        this.executed = true;
    }

    /**
     * Reset the deployment queue
     */
    flush() {
        this.deploymentQueue = [];
        this.buildQueue = [];
        this.executed = false;
        return this;
    }

    // ***********
    // Utils
    // ***********
    private async getBuildCalls(): Promise<Multicall3.Call3Struct[]> {
        await this.buildCreationCode();

        const tapiocaDeployer = await this.getTapiocaDeployer();

        return this.buildQueue.map(
            (contract): Multicall3.Call3Struct => ({
                target: tapiocaDeployer.address,
                callData: contract.creationCode,
                allowFailure: false,
            }),
        );
    }

    /**
     * Build the creation code for each contract in the queue. For each contract, we check if it has dependencies, and build them deterministically.
     */
    private async buildCreationCode() {
        const tapiocaDeployer = await this.getTapiocaDeployer();

        this.deploymentQueue.forEach(async (contract) => {
            // Build dependencies if any
            contract.dependsOn?.forEach((dependency) => {
                // Find the dependency
                const deps = this.buildQueue.find(
                    (e) => e.deploymentName === dependency.deploymentName,
                );
                // Throw if not found
                if (!deps) {
                    throw new Error(
                        `[-] Dependency ${dependency.deploymentName} not found for ${contract.deploymentName}}`,
                    );
                }
                // Set the dependency address in the contract args
                contract.args[dependency.argPosition] =
                    deps.deterministicAddress;
            });

            const creationCode = contract.contract.interface.encodeDeploy(
                contract.args,
            );
            const salt = this.genSalt();

            this.buildQueue.push({
                ...contract,
                deterministicAddress: await this.computeDeterministicAddress(
                    tapiocaDeployer,
                    salt,
                    creationCode,
                ),
                creationCode,
                salt,
            });
        });
    }

    private computeDeterministicAddress(
        deployer: TapiocaDeployer,
        salt: string,
        bytecode: string,
    ) {
        return deployer.callStatic['computeAddress(bytes32,bytes32)'](
            salt,
            this.hre.ethers.utils.keccak256(bytecode),
        );
    }
    private async getTapiocaDeployer(): Promise<TapiocaDeployer> {
        if (this.#tapiocaDeployer) return this.#tapiocaDeployer;

        // Get deployer deployment
        const deployment = this.hre.SDK.db.getLocalDeployment(
            String(this.hre.network.config.chainId),
            'TapiocaDeployer',
            this.tag,
        );

        // Deploy TapiocaDeployer if not deployed
        if (!deployment) {
            // Deploy TapiocaDeployer
            const tapiocaDeployer = await (
                await this.hre.ethers.getContractFactory('TapiocaDeployer')
            ).deploy();
            await tapiocaDeployer.deployTransaction.wait(3);

            // Save deployment
            this.hre.SDK.db.buildLocalDatabase({
                chainId: String(this.hre.network.config.chainId),
                tag: this.tag,
                contracts: [
                    {
                        address: tapiocaDeployer.address,
                        name: 'TapiocaDeployer',
                        meta: {},
                    },
                ],
            });

            this.#tapiocaDeployer = tapiocaDeployer;
            return tapiocaDeployer;
        }

        // Return TapiocaDeployer
        return this.hre.ethers.getContractAt(
            'TapiocaDeployer',
            deployment.address,
        );
    }

    private genSalt() {
        return this.hre.ethers.utils.keccak256(uuidv4());
    }
}

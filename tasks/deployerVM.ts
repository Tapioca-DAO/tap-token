import { Contract, ContractFactory } from 'ethers';
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
    contract: ContractFactory;
    args: unknown[];
    dependsOn?: IDependentOn[];
}

interface TDeploymentVMContract extends TContract {
    meta: { args: unknown[]; salt: string; create2: true };
}

interface IConstructorOptions {
    multicall: Multicall3;
    tag?: string;
}

export interface IDeployerVMAdd<T extends ContractFactory>
    extends IDeploymentQueue {
    contract: T;
    args: Parameters<T['deploy']>;
}

// TODO - Already deployed contract loader? (To verify?)
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

    hre: HardhatRuntimeEnvironment;
    options: IConstructorOptions;

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

    constructor(hre: HardhatRuntimeEnvironment, options: IConstructorOptions) {
        this.hre = hre;
        this.options = options;
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
        if (!this.executed) {
            throw new Error('[-] Deployment queue has not been executed yet');
        }

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
    // Exec
    // ***********

    /**
     * Add a contract to the deployment queue
     */
    add<T extends ContractFactory>(contract: IDeployerVMAdd<T>) {
        // Validate contract dependencies
        contract.dependsOn?.forEach((dependency) => {
            if (dependency.argPosition >= contract.args.length) {
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
     * @param wait Number of blocks to wait for the transaction to be mined. Default: 0
     */
    async execute(wait = 0) {
        const calls = await this.getBuildCalls();

        const tx = await this.options.multicall.aggregate3(calls);
        console.log('[+] Executing deployment queue on ', tx.hash);
        await tx.wait(wait);
        this.executed = true;
        console.log('[+] Deployment queue executed');

        return this;
    }

    /**
     * Save the deployments to the local database.
     */
    save() {
        if (!this.executed) {
            throw new Error(
                '[-] Deployment queue has not been executed. Please call execute() before writing the deployment file',
            );
        }

        const dep = this.hre.SDK.db.buildLocalDeployment({
            chainId: String(this.hre.network.config.chainId),
            contracts: this.list(),
        });
        this.hre.SDK.db.saveLocally(dep, this.options.tag);
        console.log(
            '[+] Deployment saved for chainId: ',
            String(this.hre.network.config.chainId),
        );

        return this;
    }

    /**
     *
     * Verify the deployed contracts on Etherscan.
     */
    async verify() {
        console.log('[+] Verifying deployed contracts');
        type TVerificationObject = {
            contract?: string;
            address: string;
            constructorArguments: unknown[];
        };

        // We will batch the verification calls to avoid hitting the etherscan API rate limit, max 5 calls per second
        const verifyList: TVerificationObject[][] = [[]];

        let counter = 1;
        for (const contract of this.list()) {
            if (counter % 5 === 0) {
                verifyList.push([]);
            }

            verifyList[verifyList.length - 1].push({
                //TODO for testing purpose, remove later
                ...(contract.name === 'YieldBoxMock'
                    ? {
                          contract:
                              'contracts/options/mocks/YieldBoxMock.sol:YieldBoxMock',
                      }
                    : {}),
                address: contract.address,
                constructorArguments: contract.meta.args,
            });
            counter++;
        }
        // Verify the contracts

        for (const batch of verifyList) {
            await Promise.all(
                batch.map((contract) =>
                    this.hre.run('verify:verify', {
                        ...contract,
                        noCompile: true,
                    }),
                ),
            );
        }

        return this;
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
                callData: this.buildDeployerCode(
                    tapiocaDeployer,
                    0,
                    contract.salt,
                    contract.creationCode,
                ),
                allowFailure: false,
            }),
        );
    }

    /**
     * Build the bytecode for the TapiocaDeployer 'deploy' function
     */
    private buildDeployerCode(
        tapiocaDeployer: TapiocaDeployer,
        amount: number,
        salt: string,
        creationCode: string,
    ) {
        return tapiocaDeployer.interface.encodeFunctionData('deploy', [
            amount,
            salt,
            creationCode,
        ]);
    }

    /**
     * Build the creation code for each contract in the queue. For each contract, we check if it has dependencies, and build them deterministically.
     */
    private async buildCreationCode() {
        const tapiocaDeployer = await this.getTapiocaDeployer();

        for (const contract of this.deploymentQueue) {
            {
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

                // Build the creation code
                const creationCode =
                    contract.contract.bytecode +
                    contract.contract.interface
                        .encodeDeploy(contract.args)
                        .split('x')[1];

                const salt = this.genSalt();

                this.buildQueue.push({
                    ...contract,
                    deterministicAddress:
                        await this.computeDeterministicAddress(
                            tapiocaDeployer,
                            salt,
                            creationCode,
                        ),
                    creationCode,
                    salt,
                });
            }
        }
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
        let deployment: TContract | undefined;
        try {
            deployment = this.hre.SDK.db.getLocalDeployment(
                String(this.hre.network.config.chainId),
                'TapiocaDeployer',
                this.options.tag,
            );
        } catch (e) {}

        // Deploy TapiocaDeployer if not deployed
        if (!deployment) {
            // Deploy TapiocaDeployer
            const tapiocaDeployer = await (
                await this.hre.ethers.getContractFactory('TapiocaDeployer')
            ).deploy();
            await tapiocaDeployer.deployTransaction.wait(3);

            // Save deployment
            const dep = this.hre.SDK.db.buildLocalDeployment({
                chainId: String(this.hre.network.config.chainId),
                contracts: [
                    {
                        address: tapiocaDeployer.address,
                        name: 'TapiocaDeployer',
                        meta: {},
                    },
                ],
            });
            this.hre.SDK.db.saveLocally(dep, this.options.tag);

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
        return this.hre.ethers.utils.solidityKeccak256(['string'], [uuidv4()]);
    }
}

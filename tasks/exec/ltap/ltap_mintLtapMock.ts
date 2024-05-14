import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadLocalContract } from 'tapioca-sdk';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';
import fs from 'fs';

export const ltap_mintLtapMock__task = async (
    _taskArgs: TTapiocaDeployTaskArgs & { userFile: string },
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(
        _taskArgs,
        { hre },
        // eslint-disable-next-line @typescript-eslint/no-empty-function
        async () => {},
        tapiocaTask,
    );
};

async function tapiocaTask(
    params: TTapiocaDeployerVmPass<{ userFile: string }>,
) {
    // Settings
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet, chainInfo } =
        params;
    const { tag, userFile } = taskArgs;

    const ltap = await hre.ethers.getContractAt(
        'LTapMock',
        loadLocalContract(hre, chainInfo.chainId, DEPLOYMENT_NAMES.LTAP, tag)
            .address,
    );
    // get the json data in the userFile
    const jsonData = (await getJsonData(userFile)) as {
        user: string;
        amount: string;
    }[];

    const users: string[] = [];
    const amounts: string[] = [];
    jsonData.forEach((data) => {
        users.push(data.user);
        amounts.push(data.amount);
    });

    await VM.executeMulticall([
        {
            target: ltap.address,
            allowFailure: false,
            callData: ltap.interface.encodeFunctionData('mint', [
                users,
                amounts,
            ]),
        },
    ]);
}

async function getJsonData(filePath: string) {
    const fileData = fs.readFileSync(filePath, 'utf-8');
    const jsonData = JSON.parse(fileData);
    return jsonData;
}

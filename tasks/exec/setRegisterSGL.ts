import { HardhatRuntimeEnvironment } from 'hardhat/types';
import inquirer from 'inquirer';
import { TAPIOCA_PROJECTS_NAME } from '../../gitsub_tapioca-sdk/src/api/config';
import { Singularity__factory } from '../../gitsub_tapioca-sdk/src/typechain/tapioca-bar/factories/markets/singularity';
import { TContract } from 'tapioca-sdk/dist/shared';

export const setRegisterSGL__task = async (
    {},
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');

    const tOLPDep = await hre.SDK.hardhatUtils.getLocalContract(
        hre,
        'TapiocaOptionLiquidityProvision',
        tag,
    );
    const tOLP = await hre.ethers.getContractAt(
        'TapiocaOptionLiquidityProvision',
        tOLPDep.contract.address,
    );

    const choices = hre.SDK.db
        .loadGlobalDeployment(
            tag,
            TAPIOCA_PROJECTS_NAME.TapiocaBar,
            await hre.getChainId(),
        )
        .filter((e) => !!e.meta.isSGLMarket);

    const { sglToRegister } = await inquirer.prompt({
        type: 'checkbox',
        name: 'sglToRegister',
        message: 'Choose a Singularity market',
        choices,
    });
    const filteredChoices: TContract[] = sglToRegister.map((e: any) =>
        choices.find((c) => c.name === e),
    );

    for (const e of filteredChoices) {
        const sgl = Singularity__factory.connect(
            e.address,
            hre.ethers.provider,
        );
        const assetID = await sgl.collateralId();
        await tOLP.registerSingularity(sgl.address, assetID, 1);
    }
};

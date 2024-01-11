import { HardhatRuntimeEnvironment } from 'hardhat/types';
import inquirer from 'inquirer';
import { TAPIOCA_PROJECTS_NAME } from '../../gitsub_tapioca-sdk/src/api/config';
import { Singularity__factory } from '../../gitsub_tapioca-sdk/src/typechain/tapioca-bar/factories/markets/singularity';
import { TContract } from 'tapioca-sdk/dist/shared';
import { ERC20WithoutStrategy__factory } from '../../gitsub_tapioca-sdk/src/typechain/YieldBox';
import {
    YieldBox__factory,
    YieldBox,
} from '../../gitsub_tapioca-sdk/src/typechain/YieldBox';
import { TapiocaOptionLiquidityProvision } from '../../typechain';

export const setRegisterSGLOnTOLP__task = async (
    {},
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const signer = (await hre.ethers.getSigners())[0];

    const tOLPDep = await hre.SDK.hardhatUtils.getLocalContract(
        hre,
        'TapiocaOptionLiquidityProvision',
        tag,
    );
    const tOLP = await hre.ethers.getContractAt(
        'TapiocaOptionLiquidityProvision',
        tOLPDep.contract.address,
    );
    const yieldBox = YieldBox__factory.connect(await tOLP.yieldBox(), signer);

    const choices = hre.SDK.db
        .loadGlobalDeployment(
            tag,
            TAPIOCA_PROJECTS_NAME.TapiocaBar,
            await hre.getChainId(),
        )
        .filter((e) => !!e.meta.isSGLMarket);

    let { sglToRegister } = await inquirer.prompt({
        type: 'checkbox',
        name: 'sglToRegister',
        message: 'Choose a Singularity market',
        choices,
    });

    // Do it manually
    if (sglToRegister.length !== 0) {
        const filteredChoices: TContract[] = sglToRegister.map((e: any) =>
            choices.find((c) => c.name === e),
        );

        for (const e of filteredChoices) {
            deployYbStratAndRegisterSgl(hre, e, signer, yieldBox, tOLP);
        }
    } else {
        sglToRegister = (
            await inquirer.prompt({
                type: 'input',
                name: 'sglToRegister',
                message: 'Input a Singularity market',
            })
        ).sglToRegister;
        await deployYbStratAndRegisterSgl(
            hre,
            {
                address: sglToRegister,
                name: 'setRegisterSgl__Name_Default',
                meta: {},
            } as TContract,
            signer,
            yieldBox,
            tOLP,
        );
    }
};

async function deployYbStratAndRegisterSgl(
    hre: HardhatRuntimeEnvironment,
    contract: TContract,
    signer: any,
    yieldBox: YieldBox,
    tOLP: TapiocaOptionLiquidityProvision,
) {
    const sgl = Singularity__factory.connect(
        contract.address,
        hre.ethers.provider,
    );

    const strategy = await new ERC20WithoutStrategy__factory(signer).deploy(
        yieldBox.address,
        sgl.address,
    );
    await strategy.deployed();

    await (
        await yieldBox.registerAsset(1, sgl.address, strategy.address, 0)
    ).wait(3);

    const assetID = await yieldBox.ids(1, sgl.address, strategy.address, 0);
    const tx = await tOLP.registerSingularity(sgl.address, assetID, 1);
    console.log(
        '[+] Registering Singularity market: ',
        await sgl.name(),
        'with assetID',
        assetID.toNumber(),
    );
    console.log('[+] Transaction hash: ', tx.hash);
    await tx.wait(3);
}

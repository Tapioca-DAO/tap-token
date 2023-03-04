import { defineConfig } from '@wagmi/cli';
import { hardhat, react, actions } from '@wagmi/cli/plugins';

export default defineConfig({
    out: 'src/generated.ts',
    contracts: [],
    plugins: [
        actions({
            readContract: true,
            writeContract: true,
            getContract: false,
            prepareWriteContract: false,
            watchContractEvent: false,
        }),
        react({
            useContractEvent: false,
            useContractFunctionRead: true,
            useContractFunctionWrite: false,
            useContractItemEvent: false,
            useContractRead: true,
            useContractWrite: false,
            usePrepareContractFunctionWrite: false,
            usePrepareContractWrite: false,
        }),
        hardhat({
            project: '../../tap-token',
            commands: {
                build: 'npx hardhat compile',
            },
            include: [
                'OFT20',
                'TapOFT',
                'ERC20Mock',
                'OracleMock',
                'OTAP',
                'TapiocaOptionBroker',
                'TapiocaOptionBrokerMock',
                'TapiocaOptionLiquidityProvision',
                'Vesting',
                'YieldBox',
            ].map((e) => `${e}.json`),
        }),
    ],
});

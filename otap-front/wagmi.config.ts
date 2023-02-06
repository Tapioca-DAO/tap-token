import { defineConfig } from '@wagmi/cli';
import { hardhat, react } from '@wagmi/cli/plugins';

export default defineConfig({
    out: 'src/generated.ts',
    contracts: [],
    plugins: [
        react({
            useContractEvent: false,
            useContractFunctionRead: true,
            useContractFunctionWrite: false,
            useContractItemEvent: false,
            useContractRead: false,
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
            ].map((e) => `${e}.json`),
        }),
    ],
});

import { defineConfig } from '@wagmi/cli';
import { hardhat, react } from '@wagmi/cli/plugins';

export default defineConfig({
    out: 'src/generated.ts',
    contracts: [],
    plugins: [
        react(),
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
                'TapiocaOptionLiquidityProvision',
                'Vesting',
            ].map((e) => `${e}.json`),
        }),
    ],
});

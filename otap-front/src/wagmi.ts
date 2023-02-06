import { getDefaultClient } from 'connectkit';
import { Chain, createClient } from 'wagmi';

const GOERLI_CHAIN: Chain = {
    id: 5,
    name: 'Goerli',
    nativeCurrency: {
        decimals: 18,
        name: 'Goerli Ether',
        symbol: 'GoETH',
    },
    network: 'Goerli',
    rpcUrls: {
        default: { http: ['https://eth-goerli.g.alchemy.com/v2/631U-TWNMURg0u4lIqrjat0LraWguV6p'] },
        public: { http: ['https://eth-goerli.alchemyapi.io/v2/631U-TWNMURg0u4lIqrjat0LraWguV6p'] },
    },
    testnet: true,
};
export const client = createClient(
    getDefaultClient({
        autoConnect: true,
        appName: 'oTAP prototype',
        chains: [GOERLI_CHAIN],
    }),
);

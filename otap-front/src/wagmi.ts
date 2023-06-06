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
        default: {
            http: [
                'https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161',
            ],
        },
        public: {
            http: [
                'https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161',
            ],
        },
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

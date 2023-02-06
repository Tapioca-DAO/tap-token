import { ConnectKitButton } from 'connectkit';
import { useAccount } from 'wagmi';

import { Account } from './components';

export function App() {
    const { isConnected } = useAccount();
    return (
        <>
            <h1>oTAP protoype</h1>
            <ConnectKitButton />
            {isConnected && <Account />}
        </>
    );
}

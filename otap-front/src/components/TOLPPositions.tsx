import { Button, Grid, Typography } from '@mui/material';
import { Alchemy, Network } from 'alchemy-sdk';
import { useEffect, useState } from 'react';
import { useAccount, useBlockNumber, useProvider, useSigner } from 'wagmi';
import { ADDRESSES } from '../addresses';
import {
    useErc20MockSymbol,
    useTapiocaOptionLiquidityProvision,
    useTapiocaOptionLiquidityProvisionGetLock,
    useTapiocaOptionLiquidityProvisionSglAssetIdToAddress,
    useYieldBoxBalanceOf,
} from '../generated';
import { formatBigNumber } from '../utils';

const useGetNFts = () => {
    const { address } = useAccount();

    const block = useBlockNumber({
        onBlock: (e) => {
            setTimeout(() => block.refetch(), 5000);
        },
    });
    const [tokens, setTokens] = useState<string[]>([]);

    useEffect(() => {
        if (address) {
            (async () => {
                const alchemy = new Alchemy({
                    network: Network.ETH_GOERLI,
                    apiKey: '631U-TWNMURg0u4lIqrjat0LraWguV6p',
                });
                const nfts = await alchemy.nft.getNftsForOwner(address, { contractAddresses: [ADDRESSES.tOLP as any] });
                const filtered = nfts.ownedNfts.map((e) => e.tokenId);
                setTokens(filtered);
            })();
        }
    }, [block.data]);

    return tokens;
};

function TOLPLock(props: { id: string }) {
    const { address } = useAccount();
    const { data: signer } = useSigner();
    const provider = useProvider();

    const tOLP = useTapiocaOptionLiquidityProvision({ address: ADDRESSES.tOLP as any, signerOrProvider: signer });
    const { data: lock } = useTapiocaOptionLiquidityProvisionGetLock({ address: ADDRESSES.tOLP as any, args: [props.id] });

    const { data: tknAddress } = useTapiocaOptionLiquidityProvisionSglAssetIdToAddress({
        address: ADDRESSES.tOLP as any,
        args: [lock?.[1].sglAssetID ?? ''],
    });
    const { data: tknSymbol } = useErc20MockSymbol({ address: tknAddress });
    const [timeRemaining, setTimeRemaining] = useState(0);

    useEffect(() => {
        const timeOut = setTimeout(async () => {
            const block = await provider.getBlock('latest');
            const remaining = lock[1]?.lockTime.add(lock?.[1].lockDuration).sub(block.timestamp);
            if (remaining.gt(0)) {
                setTimeRemaining(Number(remaining.toString()) / 60);
            } else {
                setTimeRemaining(0);
            }
        }, 60_000); // 1 minute
        return () => clearTimeout(timeOut);
    }, []);

    const onUnlock = async () => {
        await (await tOLP?.unlock(props.id, tknAddress ?? '', address ?? '')).wait();
    };

    return (
        <Typography>
            {tknSymbol} | Amount: {formatBigNumber(lock?.[1].amount)} | Duration: {Number(lock?.[1].lockDuration.toString()) / 60} minutes |
            {timeRemaining > 0 ? (
                <>
                    Remaining: {timeRemaining} minutes
                    <Button> Participate in tOB</Button>
                </>
            ) : (
                <Button variant="text" onClick={onUnlock}>
                    Unlock
                </Button>
            )}
        </Typography>
    );
}

function TOLPPositions() {
    const { address } = useAccount();
    const { data: signer } = useSigner();

    const tokens = useGetNFts();

    return (
        <Grid container>
            {tokens.map((tokenId, i) => (
                <Grid item xs={12} key={i}>
                    <TOLPLock id={tokenId} />
                </Grid>
            ))}
        </Grid>
    );
}

export default TOLPPositions;

import { Button, Grid, Typography } from '@mui/material';
import { Alchemy, Network } from 'alchemy-sdk';
import { useEffect, useState } from 'react';
import { useAccount, useBlockNumber, useProvider, useSigner } from 'wagmi';
import { ADDRESSES } from '../addresses';
import {
    useErc20MockSymbol,
    useTapiocaOptionBrokerMock,
    useTapiocaOptionLiquidityProvision,
    useTapiocaOptionLiquidityProvisionGetLock,
    useTapiocaOptionLiquidityProvisionIsApprovedOrOwner,
    useTapiocaOptionLiquidityProvisionSglAssetIdToAddress,
    useYieldBoxBalanceOf,
} from '../generated';
import { formatBigNumber } from '../utils';

const useGetTOLPs = () => {
    const { address } = useAccount();

    const [tokens, setTokens] = useState<string[]>([]);

    useEffect(() => {
        const fetchTokens = async () => {
            if (address) {
                const alchemy = new Alchemy({
                    network: Network.ETH_GOERLI,
                    apiKey: '631U-TWNMURg0u4lIqrjat0LraWguV6p',
                });
                const nfts = await alchemy.nft.getNftsForOwner(address, {
                    contractAddresses: [ADDRESSES.tOLP as any],
                });
                const filtered = nfts.ownedNfts.map((e) => e.tokenId);
                setTokens(filtered);
            }
        };
        fetchTokens();
        const interval = setInterval(fetchTokens, 25_000);
        return () => clearInterval(interval);
    }, []);

    return tokens;
};

function TOLPLock(props: { id: string }) {
    const { address } = useAccount();
    const { data: signer } = useSigner();
    const provider = useProvider();

    const tOB = useTapiocaOptionBrokerMock({
        address: ADDRESSES.tOB as any,
        signerOrProvider: signer,
    });
    const tOLP = useTapiocaOptionLiquidityProvision({
        address: ADDRESSES.tOLP as any,
        signerOrProvider: signer,
    });
    const { data: lock } = useTapiocaOptionLiquidityProvisionGetLock({
        address: ADDRESSES.tOLP as any,
        args: [props.id],
    });

    const isTOBApproved = useTapiocaOptionLiquidityProvisionIsApprovedOrOwner({
        address: ADDRESSES.tOLP as any,
        args: [ADDRESSES.tOB, props.id],
    });

    const { data: tknAddress } =
        useTapiocaOptionLiquidityProvisionSglAssetIdToAddress({
            address: ADDRESSES.tOLP as any,
            args: [lock?.[1].sglAssetID ?? ''],
        });
    const { data: tknSymbol } = useErc20MockSymbol({ address: tknAddress });
    const [timeRemaining, setTimeRemaining] = useState(0);

    useEffect(() => {
        const fetchData = async () => {
            const block = await provider.getBlock('latest');
            const remaining = lock[1]?.lockTime
                .add(lock?.[1].lockDuration)
                .sub(block.timestamp);
            if (remaining.gt(0)) {
                setTimeRemaining(Math.ceil(Number(remaining.toString()) / 60));
            } else {
                setTimeRemaining(0);
            }
        };
        fetchData();
        const timeOut = setTimeout(fetchData, 60_000); // 1 minute
        return () => clearTimeout(timeOut);
    }, [lock]);

    const onUnlock = async () => {
        await (
            await tOLP?.unlock(props.id, tknAddress ?? '', address ?? '')
        )?.wait();
    };

    const onParticipateTob = async () => {
        await (await tOB?.participate(props.id))?.wait();
    };

    const onTOBApproval = async () => {
        await (await tOLP?.approve(ADDRESSES.tOB, props.id))?.wait();
        isTOBApproved.refetch();
    };

    return (
        <Typography>
            {tknSymbol} | Amount: {formatBigNumber(lock?.[1].amount)} |
            Duration: {Number(lock?.[1].lockDuration.toString()) / 60} minutes |{' '}
            {timeRemaining > 0 ? (
                <>
                    Remaining: {timeRemaining} minutes
                    {isTOBApproved?.data ? (
                        <Button variant="text" onClick={onParticipateTob}>
                            Participate in TOB
                        </Button>
                    ) : (
                        <Button variant="text" onClick={onTOBApproval}>
                            Approve TOB
                        </Button>
                    )}
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
    const tokens = useGetTOLPs();

    return (
        <Grid container>
            {tokens.map((tokenId, i) => (
                <Grid item xs={12} key={tokenId}>
                    <TOLPLock id={tokenId} />
                </Grid>
            ))}
        </Grid>
    );
}

export default TOLPPositions;

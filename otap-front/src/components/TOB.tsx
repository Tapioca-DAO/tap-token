import { Button, Grid, TextField, Typography } from '@mui/material';
import { Alchemy, Network } from 'alchemy-sdk';
import { BigNumber } from 'ethers';
import React, { useEffect, useMemo, useState } from 'react';
import { useAccount, useSigner, useProvider, useBlockNumber } from 'wagmi';
import { ADDRESSES } from '../addresses';
import {
    useTapiocaOptionBrokerMock,
    useTapiocaOptionLiquidityProvision,
    useTapiocaOptionLiquidityProvisionGetLock,
    useTapiocaOptionLiquidityProvisionSglAssetIdToAddress,
    useErc20MockSymbol,
    useOtapOptions,
    useTapiocaOptionBrokerEpoch,
    useTapiocaOptionBrokerLastEpochUpdate,
    useErc20Mock,
    useErc20MockBalanceOf,
    useErc20MockDecimals,
} from '../generated';
import { formatBigNumber } from '../utils';

const useGetOTAP = () => {
    const { address } = useAccount();

    const [tokens, setTokens] = useState<string[]>([]);

    useEffect(() => {
        const interval = async () => {
            if (address) {
                const alchemy = new Alchemy({
                    network: Network.ETH_GOERLI,
                    apiKey: '631U-TWNMURg0u4lIqrjat0LraWguV6p',
                });
                const nfts = await alchemy.nft.getNftsForOwner(address, { contractAddresses: [ADDRESSES.oTAP as any] });
                const filtered = nfts.ownedNfts.map((e) => e.tokenId);
                setTokens(filtered);
            }
        };
        interval();
        setInterval(interval, 10_000);
        return () => clearInterval(interval);
    }, []);

    return tokens;
};

function TOBParticipation(props: { id: string }) {
    const { address } = useAccount();
    const { data: signer } = useSigner();
    const provider = useProvider();

    const tOB = useTapiocaOptionBrokerMock({ address: ADDRESSES.tOB as any, signerOrProvider: signer });

    const { data: oTapPosition } = useOtapOptions({ address: ADDRESSES.oTAP as any, args: [props.id] });
    const { data: lock } = useTapiocaOptionLiquidityProvisionGetLock({ address: ADDRESSES.tOLP as any, args: [oTapPosition?.tOLP] });

    const { data: tknAddress } = useTapiocaOptionLiquidityProvisionSglAssetIdToAddress({
        address: ADDRESSES.tOLP as any,
        args: [lock?.[1].sglAssetID ?? ''],
    });
    const { data: tknSymbol } = useErc20MockSymbol({ address: tknAddress });

    const [timeRemaining, setTimeRemaining] = useState(0);

    useEffect(() => {
        const fetchData = async () => {
            const block = await provider.getBlock('latest');
            const remaining = lock[1]?.lockTime.add(lock?.[1].lockDuration).sub(block.timestamp);
            if (remaining.gt(0)) {
                setTimeRemaining(Math.ceil(Number(remaining.toString()) / 60));
            } else {
                setTimeRemaining(0);
            }
        };
        fetchData();
        const timeOut = setInterval(fetchData, 60_000); // 1 minute
        return () => clearTimeout(timeOut);
    }, []);

    const onTOBUnlock = async () => {
        await (await tOB?.exitPosition(props.id)).wait();
    };

    return (
        <Typography>
            {tknSymbol} | Amount: {formatBigNumber(lock?.[1].amount)} | Duration: {Number(lock?.[1].lockDuration.toString()) / 60} minutes |
            Discount: {oTapPosition?.discount.div(1e4).toString()}%{' '}
            {timeRemaining > 0 ? (
                <>Remaining: {timeRemaining} minutes</>
            ) : (
                <Button variant="text" onClick={onTOBUnlock}>
                    Unlock
                </Button>
            )}
        </Typography>
    );
}

function TOBPaymentToken(props: { address: string }) {
    const { data: signer } = useSigner();
    const { address } = useAccount();

    const erc20 = useErc20Mock({ address: props.address, signerOrProvider: signer });
    const { data: tknSymbol } = useErc20MockSymbol({ address: props.address });
    const tknData = useErc20MockBalanceOf({ address: props.address, args: [address] });
    const { data: decimals } = useErc20MockDecimals({ address: props.address });

    const [mintAmount, setMintAmount] = useState('');

    const handleMint = async () => {
        await (await erc20?.freeMint(BigNumber.from(mintAmount).mul(BigNumber.from(10).pow(BigNumber.from(decimals)))))?.wait();
        await tknData?.refetch();
    };

    return (
        <>
            <Grid container direction="column" justifyContent="center">
                <Grid item>
                    <Typography style={{ textDecoration: 'underline' }}>{tknSymbol}</Typography>
                </Grid>
                <Grid item margin="5px 0px 10px 0px">
                    <Typography>Balance: {formatBigNumber(tknData?.data ?? BigNumber.from(0))}</Typography>
                </Grid>
                <Grid item alignItems="center" direction="column" container>
                    <Grid>
                        <TextField
                            value={mintAmount}
                            onChange={(e) => {
                                const value = Number(e.target.value);
                                if (value > 100_000_000) setMintAmount('100000000');
                                else if (value < 0) setMintAmount('0');
                                else setMintAmount(String(value ?? 0));
                            }}
                            size="small"
                            label="Amount"
                            InputProps={{ style: { color: 'white' } }}
                            FormHelperTextProps={{ style: { color: 'white', fontSize: '0.6rem' } }}
                            helperText="Max is 100,000,000"
                            focused
                        />
                    </Grid>
                    <Grid>
                        <Button variant="text" onClick={handleMint} disabled={Number(mintAmount) === 0}>
                            Mint
                        </Button>
                    </Grid>
                </Grid>
            </Grid>
        </>
    );
}

function TOB() {
    const { data: signer } = useSigner();

    const tokens = useGetOTAP();
    const { data: currEpoch } = useTapiocaOptionBrokerEpoch({ address: ADDRESSES.tOB as any });

    const tOB = useTapiocaOptionBrokerMock({ address: ADDRESSES.tOB as any, signerOrProvider: signer });
    const { data: lastEpochUpdate } = useTapiocaOptionBrokerLastEpochUpdate({ address: ADDRESSES.tOB as any });

    const canRequestNewEpoch = useMemo(() => {
        return Date.now() / 1000 > lastEpochUpdate?.toNumber() + 43200; // 12 hours
    }, [lastEpochUpdate]);

    const newEpoch = async () => {
        await (await tOB?.newEpoch())?.wait();
    };

    return (
        <>
            <Typography variant="h4" style={{ textDecoration: 'underline' }}>
                tOB
            </Typography>
            <Typography>Epoch duration: 12 hours</Typography>
            <Typography>
                Current epoch: {currEpoch?.toString()}
                {canRequestNewEpoch ? (
                    <>
                        <Button onClick={newEpoch}>New epoch</Button>
                    </>
                ) : null}
            </Typography>
            <Grid container>
                {tokens.map((tokenId, i) => (
                    <Grid item xs={12} key={i} style={{ border: '2px solid', borderRadius: 12, padding: 12 }}>
                        <TOBParticipation id={tokenId} />
                    </Grid>
                ))}
            </Grid>
            <Typography variant="h5" style={{ marginTop: 12 }}>
                Mint tOB payment token
            </Typography>
            <Grid container>
                {ADDRESSES['tOBPayment'].map((address, i) => (
                    <Grid item xs={12} key={i}>
                        <TOBPaymentToken address={address} />
                    </Grid>
                ))}
            </Grid>
        </>
    );
}

export default TOB;

import {
    Button,
    FormControl,
    Grid,
    InputLabel,
    MenuItem,
    Select,
    TextField,
    Typography,
} from '@mui/material';
import { Alchemy, Network } from 'alchemy-sdk';
import { BigNumber, ethers } from 'ethers';
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
    useTapiocaOptionBrokerMockGetOtcDealDetails,
    useOtapIsApprovedOrOwner,
    useOtap,
    useErc20MockAllowance,
    useTapiocaOptionBrokerMockParticipants,
    useTapiocaOptionBrokerMockOTapCalls,
    useTapiocaOptionBroker,
    useTapiocaOptionBrokerMockEpoch,
} from '../generated';
import { formatBigNumber } from '../utils';

const useGetOTAP = () => {
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
                    contractAddresses: [ADDRESSES.oTAP as any],
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

function TOBParticipation(props: { id: string }) {
    const { address } = useAccount();
    const { data: signer } = useSigner();
    const provider = useProvider();

    const tOB = useTapiocaOptionBrokerMock({
        address: ADDRESSES.tOB as any,
        signerOrProvider: signer,
    });
    const oTAP = useOtap({
        address: ADDRESSES.oTAP as any,
        signerOrProvider: signer,
    });

    const { data: oTapPosition } = useOtapOptions({
        address: ADDRESSES.oTAP as any,
        args: [props.id],
    });
    const { data: lock } = useTapiocaOptionLiquidityProvisionGetLock({
        address: ADDRESSES.tOLP as any,
        args: [oTapPosition?.tOLP],
    });

    const { data: tknAddress } =
        useTapiocaOptionLiquidityProvisionSglAssetIdToAddress({
            address: ADDRESSES.tOLP as any,
            args: [lock?.[1].sglAssetID ?? ''],
        });

    const { data: tknSymbol } = useErc20MockSymbol({ address: tknAddress });
    const [timeRemaining, setTimeRemaining] = useState(0);
    const [paymentTokenIndex, setPaymentTokenIndex] = useState(0);
    const [tapBuyAmount, setTapBuyAmount] = useState<string>('0');

    const paymentToken = useErc20Mock({
        address: ADDRESSES.tOBPayment[paymentTokenIndex].address as any,
        signerOrProvider: signer,
    });
    const otcDetails = useTapiocaOptionBrokerMockGetOtcDealDetails({
        address: ADDRESSES.tOB as any,
        args: [
            props.id,
            ADDRESSES.tOBPayment[paymentTokenIndex].address,
            BigNumber.from(tapBuyAmount).mul(BigNumber.from(10).pow(18)),
        ],
    });

    const oTAPApproval = useOtapIsApprovedOrOwner({
        address: ADDRESSES.oTAP as any,
        args: [ADDRESSES.tOB as any, props.id],
    });

    const formattedPaymentTokenAmount = useMemo(() => {
        const otcAmount = otcDetails.data?.paymentTokenAmount;
        const decimals = ADDRESSES.tOBPayment[paymentTokenIndex].decimals;
        if (otcAmount && tapBuyAmount !== '0') {
            return ethers.utils.formatUnits(otcAmount, decimals);
        }
        return 0;
    }, [otcDetails.data, tapBuyAmount]);

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
        const timeOut = setInterval(fetchData, 10_000); // 10 sec
        return () => clearInterval(timeOut);
    }, [lock]);

    const onOTAPApproval = async () => {
        await (await oTAP?.approve(ADDRESSES.tOB as any, props.id))?.wait();
        await oTAPApproval.refetch();
    };

    const onTOBUnlock = async () => {
        await (await tOB?.exitPosition(props.id)).wait();
    };

    const onTOBBuy = async () => {
        await (
            await tOB?.exerciseOption(
                props.id,
                ADDRESSES.tOBPayment[paymentTokenIndex].address,
                BigNumber.from(tapBuyAmount).mul(BigNumber.from(10).pow(18)),
            )
        )?.wait();
    };

    const { data: tokenAllowance, refetch: refetchTokenAllowance } =
        useErc20MockAllowance({
            address: ADDRESSES.tOBPayment[paymentTokenIndex].address,
            args: [address, ADDRESSES.tOB as any],
        });
    const onTokenApprove = async () => {
        await (
            await paymentToken?.approve(
                ADDRESSES.tOB as any,
                ethers.constants.MaxUint256,
            )
        ).wait();
        await refetchTokenAllowance();
    };

    const { data: epoch } = useTapiocaOptionBrokerMockEpoch({
        address: ADDRESSES.tOB as any,
    });
    const { data: tobEpochParticipation } = useTapiocaOptionBrokerMockOTapCalls(
        { address: ADDRESSES.tOB as any, args: [props.id, epoch] },
    );

    return (
        <>
            <Typography>
                {tknSymbol} | Amount: {formatBigNumber(lock?.[1].amount)} |
                Duration: {Number(lock?.[1].lockDuration.toString()) / 60}{' '}
                minutes | Discount: {oTapPosition?.discount.div(1e4).toString()}
                %{' '}
                {timeRemaining > 0 ? (
                    <>Remaining: {timeRemaining} minutes</>
                ) : oTAPApproval?.data ? (
                    <Button variant="text" onClick={onTOBUnlock}>
                        Unlock
                    </Button>
                ) : (
                    <Button variant="text" onClick={onOTAPApproval}>
                        Approve unlock
                    </Button>
                )}
            </Typography>

            {timeRemaining > 0 && tobEpochParticipation === false ? (
                <Grid container alignItems="center" style={{ marginTop: 12 }}>
                    <Grid style={{ marginRight: 12 }}>
                        <Typography>
                            Eligible for an OTC buy of{' '}
                            {formatBigNumber(
                                otcDetails.data?.eligibleTapAmount,
                            )}{' '}
                            TAP for the current epoch. Buy
                        </Typography>
                    </Grid>
                    <Grid style={{ marginRight: 12 }}>
                        <TextField
                            value={tapBuyAmount}
                            style={{ margin: '0px 10px 0px 10px' }}
                            onChange={(e) => {
                                const value = Number(e.target.value);
                                if (value < 0) setTapBuyAmount('0');
                                if (
                                    value >
                                    Number(
                                        otcDetails.data?.eligibleTapAmount
                                            .div((1e18).toString())
                                            .toString() ?? 0,
                                    )
                                )
                                    setTapBuyAmount(
                                        otcDetails.data?.eligibleTapAmount
                                            ?.div((1e18).toString())
                                            .toString() ?? '0',
                                    );
                                else setTapBuyAmount(String(value ?? 0));
                            }}
                            size="small"
                            variant="standard"
                            InputProps={{ style: { color: 'white' } }}
                        />
                    </Grid>
                    <Grid style={{ marginRight: 12 }}>
                        <Typography>
                            TAP with for a total of{' '}
                            {formattedPaymentTokenAmount}
                        </Typography>
                    </Grid>
                    <Grid>
                        <FormControl>
                            <InputLabel
                                id="demo-simple-select-label"
                                style={{ color: 'white' }}
                            >
                                Payment Token
                            </InputLabel>
                            <Select
                                labelId="demo-simple-select-label"
                                id="demo-simple-select"
                                value={paymentTokenIndex}
                                label="Payment Token"
                                style={{ color: 'white' }}
                                onChange={(e) =>
                                    setPaymentTokenIndex(Number(e.target.value))
                                }
                            >
                                {ADDRESSES.tOBPayment.map((token, i) => (
                                    <MenuItem key={token.name} value={i}>
                                        {token.name}
                                    </MenuItem>
                                ))}
                            </Select>
                        </FormControl>
                    </Grid>
                    <Grid>
                        {tokenAllowance?.isZero() ? (
                            <Button variant="text" onClick={onTokenApprove}>
                                Approve
                            </Button>
                        ) : (
                            <Button
                                variant="text"
                                onClick={onTOBBuy}
                                disabled={tobEpochParticipation}
                            >
                                Buy OTC
                            </Button>
                        )}
                    </Grid>
                </Grid>
            ) : null}
        </>
    );
}

function TOBPaymentToken(props: { address: string }) {
    const { data: signer } = useSigner();
    const { address } = useAccount();

    const erc20 = useErc20Mock({
        address: props.address,
        signerOrProvider: signer,
    });
    const { data: tknSymbol } = useErc20MockSymbol({ address: props.address });
    const tknData = useErc20MockBalanceOf({
        address: props.address,
        args: [address],
    });
    const { data: decimals } = useErc20MockDecimals({ address: props.address });

    const [mintAmount, setMintAmount] = useState('');

    const handleMint = async () => {
        await (
            await erc20?.freeMint(
                BigNumber.from(mintAmount).mul(
                    BigNumber.from(10).pow(BigNumber.from(decimals)),
                ),
            )
        )?.wait();
        await tknData?.refetch();
    };

    return (
        <>
            <Grid container direction="column" justifyContent="center">
                <Grid item>
                    <Typography style={{ textDecoration: 'underline' }}>
                        {tknSymbol}
                    </Typography>
                </Grid>
                <Grid item margin="5px 0px 10px 0px">
                    <Typography>
                        Balance:{' '}
                        {formatBigNumber(tknData?.data ?? BigNumber.from(0))}
                    </Typography>
                </Grid>
                <Grid item alignItems="center" direction="column" container>
                    <Grid>
                        <TextField
                            value={mintAmount}
                            onChange={(e) => {
                                const value = Number(e.target.value);
                                if (value > 100_000_000)
                                    setMintAmount('100000000');
                                else if (value < 0) setMintAmount('0');
                                else setMintAmount(String(value ?? 0));
                            }}
                            size="small"
                            label="Amount"
                            InputProps={{ style: { color: 'white' } }}
                            FormHelperTextProps={{
                                style: { color: 'white', fontSize: '0.6rem' },
                            }}
                            helperText="Max is 100,000,000"
                            focused
                        />
                    </Grid>
                    <Grid>
                        <Button
                            variant="text"
                            onClick={handleMint}
                            disabled={Number(mintAmount) === 0}
                        >
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
    const { data: currEpoch } = useTapiocaOptionBrokerEpoch({
        address: ADDRESSES.tOB as any,
    });

    const tOB = useTapiocaOptionBrokerMock({
        address: ADDRESSES.tOB as any,
        signerOrProvider: signer,
    });
    const { data: lastEpochUpdate } = useTapiocaOptionBrokerLastEpochUpdate({
        address: ADDRESSES.tOB as any,
    });

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
                    <Grid
                        item
                        xs={12}
                        key={i}
                        style={{
                            border: '2px solid',
                            borderRadius: 12,
                            padding: 12,
                        }}
                    >
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
                        <TOBPaymentToken address={address.address} />
                    </Grid>
                ))}
            </Grid>
        </>
    );
}

export default TOB;

import { Typography, Grid, TextField, Button } from '@mui/material';
import { useAccount, useSigner } from 'wagmi';

import { useEffect, useState } from 'react';
import { ADDRESSES } from '../addresses';
import {
    readTapiocaOptionLiquidityProvision,
    useErc20Mock,
    useErc20MockAllowance,
    useErc20MockBalanceOf,
    useErc20MockName,
    useErc20MockSymbol,
    useTapiocaOptionLiquidityProvision,
    useTapiocaOptionLiquidityProvisionGetSingularities,
    useTapiocaOptionLiquidityProvisionLockPositions,
    useTapiocaOptionLiquidityProvisionSglAssetIdToAddress,
    useYieldBox,
    useYieldBoxBalanceOf,
    useYieldBoxIsApprovedForAll,
    useYieldBoxToAmount,
} from '../generated';
import { formatBigNumber } from '../utils';
import { BigNumber, ethers } from 'ethers';
import TOLPPositions from './TOLPPositions';

function useGetTOLPAddress(assetIds: []) {
    const [tOLPs, setTOLPs] = useState<`0x${string}`[]>([]);

    useEffect(() => {
        (async () => {
            const tOLPAddresses = await Promise.all(
                assetIds
                    .map(
                        async (id) =>
                            await readTapiocaOptionLiquidityProvision({
                                address: ADDRESSES.tOLP as any,
                                functionName: 'sglAssetIDToAddress',
                                args: [id],
                            }),
                    )
                    .filter(Boolean),
            );
            setTOLPs(tOLPAddresses);
        })();
    }, [assetIds]);

    return tOLPs;
}

function TOLPToken(props: { id: BigNumber }) {
    const { address } = useAccount();
    const { data: signer } = useSigner();

    const { data: tknAddress } = useTapiocaOptionLiquidityProvisionSglAssetIdToAddress({
        address: ADDRESSES.tOLP as any,
        args: [props.id],
    });
    const tknSymbol = useErc20MockSymbol({ address: tknAddress });
    const tknData = useErc20MockBalanceOf({ address: tknAddress, args: [address ?? ''] });
    const tknMint = useErc20Mock({ address: tknAddress, signerOrProvider: signer });

    const [mintAmount, setMintAmount] = useState<string>('0');

    const handleMint = () => {
        tknMint?.freeMint(BigNumber.from(mintAmount).mul((1e18).toString())).then(async (tx) => {
            await tx.wait();
            tknData.refetch();
        });
    };

    return (
        <Grid container direction="column" justifyContent="center">
            <Grid item>
                <Typography style={{ textDecoration: 'underline' }}>{tknSymbol.data}</Typography>
            </Grid>
            <Grid item margin="5px 0px 10px 0px">
                <Typography>Balance: {formatBigNumber(tknData.data)}</Typography>
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
    );
}

function TOLPYBDeposit(props: { id: BigNumber }) {
    const { address } = useAccount();
    const { data: signer } = useSigner();

    const { data: tknAddress } = useTapiocaOptionLiquidityProvisionSglAssetIdToAddress({
        address: ADDRESSES.tOLP as any,
        args: [props.id],
    });
    const tknSymbol = useErc20MockSymbol({ address: tknAddress });
    const tknData = useErc20MockBalanceOf({ address: tknAddress, args: [address ?? ''] });
    const tkn = useErc20Mock({ address: tknAddress, signerOrProvider: signer });
    const allowance = useErc20MockAllowance({ address: tknAddress, args: [address ?? '', ADDRESSES.yieldBox] });

    const yb = useYieldBox({ address: ADDRESSES.yieldBox as any, signerOrProvider: signer });
    const { data: shareBalanceOf, refetch: refetchBalance } = useYieldBoxBalanceOf({
        address: ADDRESSES.yieldBox as any,
        args: [address ?? '', props.id],
    });
    const balanceOf = useYieldBoxToAmount({ address: ADDRESSES.yieldBox as any, args: [props.id, shareBalanceOf, false] });

    const [depositAmount, setDepositAmount] = useState<string>('0');

    useEffect(() => {
        const timeOut = setInterval(async () => await refetchBalance(), 10_000);

        return () => clearInterval(timeOut);
    }, []);

    const onApprove = async () => {
        await (await tkn?.approve(ADDRESSES.yieldBox as any, ethers.constants.MaxUint256))?.wait();
        await tknData.refetch();
        await allowance.refetch();
    };

    const onDeposit = async () => {
        await (await yb?.depositAsset(props.id, address, address, BigNumber.from(depositAmount).mul((1e18).toString()), 0))?.wait();
        await balanceOf.refetch();
        await tknData.refetch();
    };

    const onWithdraw = async () => {
        await (await yb?.withdraw(props.id, address, address, BigNumber.from(depositAmount).mul((1e18).toString()), 0)).wait();
        await balanceOf.refetch();
        await tknData.refetch();
    };

    return (
        <Typography>
            <Button variant="text" onClick={onApprove} disabled={allowance.data?.gt(0)}>
                Approve
            </Button>
            <Button variant="text" disabled={Number(depositAmount) === 0 || allowance.data?.eq(0)} onClick={onDeposit}>
                Deposit
            </Button>
            <Button variant="text" disabled={balanceOf.data?.eq(0) || allowance.data?.eq(0)} onClick={onWithdraw}>
                Withdraw
            </Button>
            <TextField
                value={depositAmount}
                style={{ margin: '0px 10px 0px 10px' }}
                onChange={(e) => {
                    const value = Number(e.target.value);
                    if (value > tknData.data!.div((1e18).toString()).toNumber())
                        setDepositAmount(tknData.data!.div((1e18).toString()).toString());
                    else if (value < 0) setDepositAmount('0');
                    else setDepositAmount(String(value ?? 0));
                }}
                size="small"
                variant="standard"
                InputProps={{ style: { color: 'white' } }}
                disabled={tknData.data?.eq(0)}
            />
            {tknSymbol.data} to/from YieldBox. Balance: {formatBigNumber(balanceOf?.data ?? BigNumber.from(0))}
        </Typography>
    );
}

function TOLPLock(props: { id: BigNumber }) {
    const { address } = useAccount();
    const { data: signer } = useSigner();
    const { data: tknAddress } = useTapiocaOptionLiquidityProvisionSglAssetIdToAddress({
        address: ADDRESSES.tOLP as any,
        args: [props.id],
    });
    const { data: tknSymbol } = useErc20MockSymbol({ address: tknAddress });

    const tOLP = useTapiocaOptionLiquidityProvision({ address: ADDRESSES.tOLP as any, signerOrProvider: signer });

    const { data: shareBalanceOf } = useYieldBoxBalanceOf({ address: ADDRESSES.yieldBox as any, args: [address ?? '', props.id] });
    const { data: balanceOf } = useYieldBoxToAmount({ address: ADDRESSES.yieldBox as any, args: [props.id, shareBalanceOf, false] });

    const yb = useYieldBox({ address: ADDRESSES.yieldBox as any, signerOrProvider: signer });
    const ybApproval = useYieldBoxIsApprovedForAll({ address: ADDRESSES.yieldBox as any, args: [address ?? '', ADDRESSES.tOLP] });

    const [depositAmount, setDepositAmount] = useState<string>('0');
    const [durationAmount, setDurationAmount] = useState<string>('0');

    const onApprove = async () => {
        await (await yb?.setApprovalForAll(ADDRESSES.tOLP as any, true))?.wait();
        await ybApproval.refetch();
    };

    const onLock = () => {
        tOLP?.lock(address, address, tknAddress, Number(durationAmount) * 60, BigNumber.from(depositAmount).mul((1e18).toString())).then(
            async (tx) => {
                await tx.wait();
            },
        );
    };

    return (
        <Typography>
            <Button variant="text" onClick={onApprove} disabled={!!ybApproval.data}>
                Approve
            </Button>
            <Button variant="text" onClick={onLock} disabled={Number(depositAmount) === 0 || Number(durationAmount) === 0}>
                Lock
            </Button>
            <TextField
                value={depositAmount}
                style={{ margin: '0px 10px 0px 10px' }}
                onChange={(e) => {
                    const value = Number(e.target.value);
                    if (value > balanceOf!.div((1e18).toString()).toNumber())
                        setDepositAmount(balanceOf!.div((1e18).toString()).toString());
                    else if (value < 0) setDepositAmount('0');
                    else setDepositAmount(String(value ?? 0));
                }}
                size="small"
                variant="standard"
                InputProps={{ style: { color: 'white' } }}
                disabled={balanceOf?.eq(0)}
            />
            {tknSymbol} for a duration of
            <TextField
                value={durationAmount}
                style={{ margin: '0px 10px 0px 10px' }}
                onChange={(e) => {
                    const value = Number(e.target.value);
                    if (value < 0) setDurationAmount('0');
                    else setDurationAmount(String(value ?? 0));
                }}
                size="small"
                variant="standard"
                InputProps={{ style: { color: 'white' } }}
                disabled={balanceOf?.eq(0)}
            />
            minutes to tOLP.
        </Typography>
    );
}

function TOLP() {
    const assetIds = useTapiocaOptionLiquidityProvisionGetSingularities({ address: ADDRESSES.tOLP as any });

    return (
        <div>
            <Typography variant="h5">Mint tOLP tokens</Typography>

            <Grid container justifyContent="space-evenly">
                {assetIds.data?.map((id, i) => (
                    <Grid item key={i}>
                        <TOLPToken id={id} />
                    </Grid>
                ))}
            </Grid>

            <Grid container direction="column">
                <Grid item>
                    <Typography variant="h5">Deposit/Withdraw tOLP tokens</Typography>
                </Grid>
                {assetIds.data?.map((id, i) => (
                    <Grid item key={i} marginTop="12px">
                        <TOLPYBDeposit id={id} />
                    </Grid>
                ))}
            </Grid>

            <Grid container direction="column">
                <Grid item>
                    <Typography variant="h5">Lock tOLP tokens</Typography>
                </Grid>
                {assetIds.data?.map((id, i) => (
                    <Grid item key={i} marginTop="12px">
                        <TOLPLock id={id} />
                    </Grid>
                ))}
            </Grid>

            <Typography variant="h5">tOLP positions</Typography>
            <div style={{ marginBottom: 12 }}>
                <TOLPPositions />
            </div>
        </div>
    );
}

export default TOLP;

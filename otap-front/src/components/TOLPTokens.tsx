import { Typography, Grid, TextField, Button } from '@mui/material';
import { useAccount, useSigner } from 'wagmi';

import { useEffect, useState } from 'react';
import { ADDRESSES } from '../addresses';
import {
    readTapiocaOptionLiquidityProvision,
    useErc20Mock,
    useErc20MockBalanceOf,
    useErc20MockName,
    useErc20MockSymbol,
    useTapiocaOptionLiquidityProvisionGetSingularities,
} from '../generated';
import { formatBigNumber } from '../utils';
import { BigNumber } from 'ethers';

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

function TOLPToken(props: { tkn: `0x${string}` }) {
    const { address } = useAccount();
    const { data: signer } = useSigner();
    const tknSymbol = useErc20MockSymbol({ address: props.tkn });
    const tknData = useErc20MockBalanceOf({ address: props.tkn, args: [address ?? ''] });
    const tknMint = useErc20Mock({ address: props.tkn, signerOrProvider: signer });

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

function TOLPTokens() {
    const assetIds = useTapiocaOptionLiquidityProvisionGetSingularities({ address: ADDRESSES.tOLP as any });
    const tOLPs = useGetTOLPAddress((assetIds.data ?? []) as any);

    return (
        <div>
            <Typography variant="h5">Whitelisted tOLP tokens</Typography>

            <Grid container justifyContent="space-evenly">
                {tOLPs.map((tOLP, i) => (
                    <Grid item key={i}>
                        <TOLPToken tkn={tOLP} />
                    </Grid>
                ))}
            </Grid>
        </div>
    );
}

export default TOLPTokens;

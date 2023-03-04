import { Typography } from '@mui/material';
import { useMemo } from 'react';
import { useAccount } from 'wagmi';
import { ADDRESSES } from '../addresses';
import { useOracleMockGet, useTapOftBalanceOf, useTapOftTotalSupply } from '../generated';
import { formatBigNumber } from '../utils';
import TOLPPositions from './TOLPPositions';

function TapOFTOverview() {
    const { address } = useAccount();

    const tapOftTotalSupply = useTapOftTotalSupply({ address: ADDRESSES.tapOFT as any });
    const tapOftBalance = useTapOftBalanceOf({
        address: ADDRESSES.tapOFT as any,
        args: [address ?? ''],
    });
    const { data: tapPrice } = useOracleMockGet({ address: ADDRESSES.tapOracle as any, args: ['0x00'] });

    const tapPriceMemo = useMemo(() => {
        if (tapPrice?._rate) {
            const decNum = tapPrice?._rate.div((1e8).toString()).toNumber();
            const decFrac = tapPrice?._rate.div((1e7).toString()).toNumber() - decNum * 10;
            return decNum + '.' + decFrac + ' USD';
        }
        return 0;
    }, [tapPrice]);

    return (
        <>
            <Typography variant="h4" style={{ textDecoration: 'underline' }}>
                TapOFT
            </Typography>
            <span>
                <Typography>Total supply: {formatBigNumber(tapOftTotalSupply.data)}</Typography>
                <Typography>$TAP PRICE: {tapPriceMemo}</Typography>
                <Typography>My tap balance: {formatBigNumber(tapOftBalance.data)}</Typography>
            </span>
        </>
    );
}

export default TapOFTOverview;

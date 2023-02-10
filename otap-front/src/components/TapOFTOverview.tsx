import { Typography } from '@mui/material';
import { useAccount } from 'wagmi';
import { ADDRESSES } from '../addresses';
import { useTapOftBalanceOf, useTapOftTotalSupply } from '../generated';
import { formatBigNumber } from '../utils';
import TOLPPositions from './TOLPPositions';

function TapOFTOverview() {
    const { address } = useAccount();

    const tapOftTotalSupply = useTapOftTotalSupply({ address: ADDRESSES.tapOFT as any });
    const tapOftBalance = useTapOftBalanceOf({
        address: ADDRESSES.tapOFT as any,
        args: [address ?? ''],
    });

    return (
        <>
            <Typography variant="h4">TapOFT</Typography>
            <span>
                <Typography>Total supply: {formatBigNumber(tapOftTotalSupply.data)}</Typography>
                <Typography>My tap balance: {formatBigNumber(tapOftBalance.data)}</Typography>
            </span>
        </>
    );
}

export default TapOFTOverview;

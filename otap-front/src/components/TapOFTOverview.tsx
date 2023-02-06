import { Typography } from '@mui/material';
import { useAccount } from 'wagmi';
import { ADDRESSES } from '../addresses';
import { useTapOftBalanceOf, useTapOftTotalSupply } from '../generated';

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
                <Typography>
                    Total supply: {new Intl.NumberFormat().format(tapOftTotalSupply.data?.div((1e18).toString()).toNumber())}
                </Typography>
                <Typography>
                    My tap balance: {new Intl.NumberFormat().format(tapOftBalance.data?.div((1e18).toString()).toNumber())}
                </Typography>
            </span>
        </>
    );
}

export default TapOFTOverview;

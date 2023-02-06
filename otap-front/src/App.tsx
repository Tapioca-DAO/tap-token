import { Grid, Typography } from '@mui/material';
import { ConnectKitButton } from 'connectkit';
import { useChainId } from 'wagmi';

import MainContainer from './components/MainContainer';
import TapOFTOverview from './components/TapOFTOverview';

export function App() {
    return (
        <>
            <Grid container justifyContent="center" direction={'column'}>
                <Grid item container justifyContent="flex-end">
                    <div style={{ marginRight: 24 }}>
                        <ConnectKitButton showAvatar />
                    </div>
                </Grid>
                <Grid item xs>
                    <MainContainer>
                        <TapOFTOverview />
                        <Grid container justifyContent="center">
                            <Grid item>
                                <Typography>Whitelisted tOLP tokens</Typography>
                            </Grid>
                        </Grid>
                    </MainContainer>
                </Grid>
            </Grid>
        </>
    );
}

import { Grid, Typography, Divider } from '@mui/material';
import { ConnectKitButton } from 'connectkit';
import { useChainId } from 'wagmi';

import MainContainer from './components/MainContainer';
import TapOFTOverview from './components/TapOFTOverview';
import TOLPTokens from './components/TOLPTokens';

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
                        <Divider style={{ height: 2, margin: '10px 0px 10px 0px' }} color="white" />
                        <Grid container justifyContent="center">
                            <Grid item width={'100%'}>
                                <TOLPTokens />
                            </Grid>
                        </Grid>
                    </MainContainer>
                </Grid>
            </Grid>
        </>
    );
}

import { css, Paper } from '@mui/material';
import React from 'react';

export default function MainContainer(props: React.PropsWithChildren) {
    return (
        <Paper
            elevation={24}
            style={{
                margin: 24,
                color: 'gainsboro',
                padding: 16,

                background: 'rgba(255, 255, 255, 0.08)',
                borderRadius: '16px',
                backdropFilter: 'blur(4.7px)',
                border: '1px solid rgba(255, 255, 255, 0.04)',
            }}
        >
            {props.children}
        </Paper>
    );
}

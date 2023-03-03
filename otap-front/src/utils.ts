import { BigNumber } from 'ethers';

export const formatBigNumber = (data?: BigNumber, decimals?: number) =>
    new Intl.NumberFormat().format(data?.div((decimals ?? 1e18).toString()));

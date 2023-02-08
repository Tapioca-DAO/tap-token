import { BigNumber } from 'ethers';

export const formatBigNumber = (data?: BigNumber) => new Intl.NumberFormat().format(data?.div((1e18).toString()).toNumber());

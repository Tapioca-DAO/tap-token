# LZEndpointMock









## Methods

### addrToPackedBytes

```solidity
function addrToPackedBytes(address _a) external pure returns (bytes)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _a | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | undefined |

### blockNextMsg

```solidity
function blockNextMsg() external nonpayable
```






### estimateFees

```solidity
function estimateFees(uint16, address, bytes _payload, bool, bytes) external view returns (uint256 _nativeFee, uint256 _zroFee)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |
| _1 | address | undefined |
| _payload | bytes | undefined |
| _3 | bool | undefined |
| _4 | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _nativeFee | uint256 | undefined |
| _zroFee | uint256 | undefined |

### forceResumeReceive

```solidity
function forceResumeReceive(uint16 _srcChainId, bytes _srcAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |

### getChainId

```solidity
function getChainId() external view returns (uint16)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

### getConfig

```solidity
function getConfig(uint16, uint16, address, uint256) external pure returns (bytes)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |
| _1 | uint16 | undefined |
| _2 | address | undefined |
| _3 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | undefined |

### getInboundNonce

```solidity
function getInboundNonce(uint16 _chainID, bytes _srcAddress) external view returns (uint64)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _chainID | uint16 | undefined |
| _srcAddress | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint64 | undefined |

### getLengthOfQueue

```solidity
function getLengthOfQueue(uint16 _srcChainId, bytes _srcAddress) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getOutboundNonce

```solidity
function getOutboundNonce(uint16 _chainID, address _srcAddress) external view returns (uint64)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _chainID | uint16 | undefined |
| _srcAddress | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint64 | undefined |

### getReceiveLibraryAddress

```solidity
function getReceiveLibraryAddress(address) external view returns (address)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getReceiveVersion

```solidity
function getReceiveVersion(address) external pure returns (uint16)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

### getSendLibraryAddress

```solidity
function getSendLibraryAddress(address) external view returns (address)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getSendVersion

```solidity
function getSendVersion(address) external pure returns (uint16)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

### hasStoredPayload

```solidity
function hasStoredPayload(uint16 _srcChainId, bytes _srcAddress) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### inboundNonce

```solidity
function inboundNonce(uint16, bytes) external view returns (uint64)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |
| _1 | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint64 | undefined |

### isReceivingPayload

```solidity
function isReceivingPayload() external pure returns (bool)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### isSendingPayload

```solidity
function isSendingPayload() external pure returns (bool)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### lzEndpointLookup

```solidity
function lzEndpointLookup(address) external view returns (address)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### mockBlockConfirmations

```solidity
function mockBlockConfirmations() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### mockChainId

```solidity
function mockChainId() external view returns (uint16)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

### mockLayerZeroVersion

```solidity
function mockLayerZeroVersion() external view returns (uint16)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

### mockLibraryVersion

```solidity
function mockLibraryVersion() external view returns (uint16)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

### mockOracle

```solidity
function mockOracle() external view returns (address payable)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address payable | undefined |

### mockRelayer

```solidity
function mockRelayer() external view returns (address payable)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address payable | undefined |

### mockStaticNativeFee

```solidity
function mockStaticNativeFee() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### msgsToDeliver

```solidity
function msgsToDeliver(uint16, bytes, uint256) external view returns (address dstAddress, uint64 nonce, bytes payload)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |
| _1 | bytes | undefined |
| _2 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| dstAddress | address | undefined |
| nonce | uint64 | undefined |
| payload | bytes | undefined |

### nativeFee

```solidity
function nativeFee() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### outboundNonce

```solidity
function outboundNonce(uint16, address) external view returns (uint64)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |
| _1 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint64 | undefined |

### packedBytesToAddr

```solidity
function packedBytesToAddr(bytes _b) external pure returns (address)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _b | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### receivePayload

```solidity
function receivePayload(uint16 _srcChainId, bytes _srcAddress, address _dstAddress, uint64 _nonce, uint256, bytes _payload) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |
| _dstAddress | address | undefined |
| _nonce | uint64 | undefined |
| _4 | uint256 | undefined |
| _payload | bytes | undefined |

### retryPayload

```solidity
function retryPayload(uint16 _srcChainId, bytes _srcAddress, bytes _payload) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |
| _payload | bytes | undefined |

### send

```solidity
function send(uint16 _chainId, bytes _destination, bytes _payload, address payable, address, bytes _adapterParams) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _chainId | uint16 | undefined |
| _destination | bytes | undefined |
| _payload | bytes | undefined |
| _3 | address payable | undefined |
| _4 | address | undefined |
| _adapterParams | bytes | undefined |

### setConfig

```solidity
function setConfig(uint16, uint16, uint256, bytes) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |
| _1 | uint16 | undefined |
| _2 | uint256 | undefined |
| _3 | bytes | undefined |

### setDestLzEndpoint

```solidity
function setDestLzEndpoint(address destAddr, address lzEndpointAddr) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| destAddr | address | undefined |
| lzEndpointAddr | address | undefined |

### setEstimatedFees

```solidity
function setEstimatedFees(uint256 _nativeFee, uint256 _zroFee) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _nativeFee | uint256 | undefined |
| _zroFee | uint256 | undefined |

### setReceiveVersion

```solidity
function setReceiveVersion(uint16) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

### setSendVersion

```solidity
function setSendVersion(uint16) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

### storedPayload

```solidity
function storedPayload(uint16, bytes) external view returns (uint64 payloadLength, address dstAddress, bytes32 payloadHash)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |
| _1 | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| payloadLength | uint64 | undefined |
| dstAddress | address | undefined |
| payloadHash | bytes32 | undefined |

### zroFee

```solidity
function zroFee() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |



## Events

### PayloadCleared

```solidity
event PayloadCleared(uint16 srcChainId, bytes srcAddress, uint64 nonce, address dstAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| srcChainId  | uint16 | undefined |
| srcAddress  | bytes | undefined |
| nonce  | uint64 | undefined |
| dstAddress  | address | undefined |

### PayloadStored

```solidity
event PayloadStored(uint16 srcChainId, bytes srcAddress, address dstAddress, uint64 nonce, bytes payload, bytes reason)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| srcChainId  | uint16 | undefined |
| srcAddress  | bytes | undefined |
| dstAddress  | address | undefined |
| nonce  | uint64 | undefined |
| payload  | bytes | undefined |
| reason  | bytes | undefined |

### UaForceResumeReceive

```solidity
event UaForceResumeReceive(uint16 chainId, bytes srcAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| chainId  | uint16 | undefined |
| srcAddress  | bytes | undefined |




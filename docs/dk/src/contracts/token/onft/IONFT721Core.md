# IONFT721Core







*Interface of the ONFT Core standard*

## Methods

### estimateSendBatchFee

```solidity
function estimateSendBatchFee(uint16 _dstChainId, bytes _toAddress, uint256[] _tokenIds, bool _useZro, bytes _adapterParams) external view returns (uint256 nativeFee, uint256 zroFee)
```



*estimate send token `_tokenId` to (`_dstChainId`, `_toAddress`) _dstChainId - L0 defined chain id to send tokens too _toAddress - dynamic bytes array which contains the address to whom you are sending tokens to on the dstChain _tokenIds[] - token Ids to transfer _useZro - indicates to use zro to pay L0 fees _adapterParams - flexible bytes array to indicate messaging adapter services in L0*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _toAddress | bytes | undefined |
| _tokenIds | uint256[] | undefined |
| _useZro | bool | undefined |
| _adapterParams | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| nativeFee | uint256 | undefined |
| zroFee | uint256 | undefined |

### estimateSendFee

```solidity
function estimateSendFee(uint16 _dstChainId, bytes _toAddress, uint256 _tokenId, bool _useZro, bytes _adapterParams) external view returns (uint256 nativeFee, uint256 zroFee)
```



*estimate send token `_tokenId` to (`_dstChainId`, `_toAddress`) _dstChainId - L0 defined chain id to send tokens too _toAddress - dynamic bytes array which contains the address to whom you are sending tokens to on the dstChain _tokenId - token Id to transfer _useZro - indicates to use zro to pay L0 fees _adapterParams - flexible bytes array to indicate messaging adapter services in L0*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _toAddress | bytes | undefined |
| _tokenId | uint256 | undefined |
| _useZro | bool | undefined |
| _adapterParams | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| nativeFee | uint256 | undefined |
| zroFee | uint256 | undefined |

### sendBatchFrom

```solidity
function sendBatchFrom(address _from, uint16 _dstChainId, bytes _toAddress, uint256[] _tokenIds, address payable _refundAddress, address _zroPaymentAddress, bytes _adapterParams) external payable
```



*send tokens `_tokenIds[]` to (`_dstChainId`, `_toAddress`) from `_from` `_toAddress` can be any size depending on the `dstChainId`. `_zroPaymentAddress` set to address(0x0) if not paying in ZRO (LayerZero Token) `_adapterParams` is a flexible bytes array to indicate messaging adapter services*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | undefined |
| _dstChainId | uint16 | undefined |
| _toAddress | bytes | undefined |
| _tokenIds | uint256[] | undefined |
| _refundAddress | address payable | undefined |
| _zroPaymentAddress | address | undefined |
| _adapterParams | bytes | undefined |

### sendFrom

```solidity
function sendFrom(address _from, uint16 _dstChainId, bytes _toAddress, uint256 _tokenId, address payable _refundAddress, address _zroPaymentAddress, bytes _adapterParams) external payable
```



*send token `_tokenId` to (`_dstChainId`, `_toAddress`) from `_from` `_toAddress` can be any size depending on the `dstChainId`. `_zroPaymentAddress` set to address(0x0) if not paying in ZRO (LayerZero Token) `_adapterParams` is a flexible bytes array to indicate messaging adapter services*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | undefined |
| _dstChainId | uint16 | undefined |
| _toAddress | bytes | undefined |
| _tokenId | uint256 | undefined |
| _refundAddress | address payable | undefined |
| _zroPaymentAddress | address | undefined |
| _adapterParams | bytes | undefined |

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) external view returns (bool)
```



*Returns true if this contract implements the interface defined by `interfaceId`. See the corresponding https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section] to learn more about how these ids are created. This function call must use less than 30 000 gas.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| interfaceId | bytes4 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |



## Events

### CreditCleared

```solidity
event CreditCleared(bytes32 _hashedPayload)
```



*Emitted when `_hashedPayload` has been completely delivered*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _hashedPayload  | bytes32 | undefined |

### CreditStored

```solidity
event CreditStored(bytes32 _hashedPayload, bytes _payload)
```



*Emitted when `_payload` was received from lz, but not enough gas to deliver all tokenIds*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _hashedPayload  | bytes32 | undefined |
| _payload  | bytes | undefined |

### ReceiveFromChain

```solidity
event ReceiveFromChain(uint16 indexed _srcChainId, bytes indexed _srcAddress, address indexed _toAddress, uint256[] _tokenIds)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId `indexed` | uint16 | undefined |
| _srcAddress `indexed` | bytes | undefined |
| _toAddress `indexed` | address | undefined |
| _tokenIds  | uint256[] | undefined |

### SendToChain

```solidity
event SendToChain(uint16 indexed _dstChainId, address indexed _from, bytes indexed _toAddress, uint256[] _tokenIds)
```



*Emitted when `_tokenIds[]` are moved from the `_sender` to (`_dstChainId`, `_toAddress`) `_nonce` is the outbound nonce from*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId `indexed` | uint16 | undefined |
| _from `indexed` | address | undefined |
| _toAddress `indexed` | bytes | undefined |
| _tokenIds  | uint256[] | undefined |




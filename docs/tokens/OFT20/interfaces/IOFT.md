# IOFT







*Interface of the OFT standard*

## Methods

### allowance

```solidity
function allowance(address owner, address spender) external view returns (uint256)
```



*Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `owner` through {transferFrom}. This is zero by default. This value changes when {approve} or {transferFrom} are called.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |
| spender | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### approve

```solidity
function approve(address spender, uint256 amount) external nonpayable returns (bool)
```



*Sets `amount` as the allowance of `spender` over the caller&#39;s tokens. Returns a boolean value indicating whether the operation succeeded. IMPORTANT: Beware that changing an allowance with this method brings the risk that someone may use both the old and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this race condition is to first reduce the spender&#39;s allowance to 0 and set the desired value afterwards: https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729 Emits an {Approval} event.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### balanceOf

```solidity
function balanceOf(address account) external view returns (uint256)
```



*Returns the amount of tokens owned by `account`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### circulatingSupply

```solidity
function circulatingSupply() external view returns (uint256)
```



*returns the circulating amount of tokens on current chain*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### estimateSendFee

```solidity
function estimateSendFee(uint16 _dstChainId, bytes _toAddress, uint256 _amount, bool _useZro, bytes _adapterParams) external view returns (uint256 nativeFee, uint256 zroFee)
```



*estimate send token `_tokenId` to (`_dstChainId`, `_toAddress`) _dstChainId - L0 defined chain id to send tokens too _toAddress - dynamic bytes array which contains the address to whom you are sending tokens to on the dstChain _amount - amount of the tokens to transfer _useZro - indicates to use zro to pay L0 fees _adapterParam - flexible bytes array to indicate messaging adapter services in L0*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _toAddress | bytes | undefined |
| _amount | uint256 | undefined |
| _useZro | bool | undefined |
| _adapterParams | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| nativeFee | uint256 | undefined |
| zroFee | uint256 | undefined |

### sendFrom

```solidity
function sendFrom(address _from, uint16 _dstChainId, bytes _toAddress, uint256 _amount, address payable _refundAddress, address _zroPaymentAddress, bytes _adapterParams) external payable
```



*send `_amount` amount of token to (`_dstChainId`, `_toAddress`) from `_from` `_from` the owner of token `_dstChainId` the destination chain identifier `_toAddress` can be any size depending on the `dstChainId`. `_amount` the quantity of tokens in wei `_refundAddress` the address LayerZero refunds if too much message fee is sent `_zroPaymentAddress` set to address(0x0) if not paying in ZRO (LayerZero Token) `_adapterParams` is a flexible bytes array to indicate messaging adapter services*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | undefined |
| _dstChainId | uint16 | undefined |
| _toAddress | bytes | undefined |
| _amount | uint256 | undefined |
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

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```



*Returns the amount of tokens in existence.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### transfer

```solidity
function transfer(address to, uint256 amount) external nonpayable returns (bool)
```



*Moves `amount` tokens from the caller&#39;s account to `to`. Returns a boolean value indicating whether the operation succeeded. Emits a {Transfer} event.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 amount) external nonpayable returns (bool)
```



*Moves `amount` tokens from `from` to `to` using the allowance mechanism. `amount` is then deducted from the caller&#39;s allowance. Returns a boolean value indicating whether the operation succeeded. Emits a {Transfer} event.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |



## Events

### Approval

```solidity
event Approval(address indexed owner, address indexed spender, uint256 value)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| spender `indexed` | address | undefined |
| value  | uint256 | undefined |

### ReceiveFromChain

```solidity
event ReceiveFromChain(uint16 indexed _srcChainId, bytes indexed _srcAddress, address indexed _toAddress, uint256 _amount, uint64 _nonce)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId `indexed` | uint16 | undefined |
| _srcAddress `indexed` | bytes | undefined |
| _toAddress `indexed` | address | undefined |
| _amount  | uint256 | undefined |
| _nonce  | uint64 | undefined |

### SendToChain

```solidity
event SendToChain(address indexed _sender, uint16 indexed _dstChainId, bytes indexed _toAddress, uint256 _amount, uint64 _nonce)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _sender `indexed` | address | undefined |
| _dstChainId `indexed` | uint16 | undefined |
| _toAddress `indexed` | bytes | undefined |
| _amount  | uint256 | undefined |
| _nonce  | uint64 | undefined |

### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 value)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| from `indexed` | address | undefined |
| to `indexed` | address | undefined |
| value  | uint256 | undefined |




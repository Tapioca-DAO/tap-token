# TwTAP









## Methods

### DEFAULT_PAYLOAD_SIZE_LIMIT

```solidity
function DEFAULT_PAYLOAD_SIZE_LIMIT() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### DOMAIN_SEPARATOR

```solidity
function DOMAIN_SEPARATOR() external view returns (bytes32)
```



*See {IERC20Permit-DOMAIN_SEPARATOR}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### EPOCH_DURATION

```solidity
function EPOCH_DURATION() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### FUNCTION_TYPE_SEND

```solidity
function FUNCTION_TYPE_SEND() external view returns (uint16)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

### HOST_CHAIN_ID

```solidity
function HOST_CHAIN_ID() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### addRewardToken

```solidity
function addRewardToken(contract IERC20 token) external nonpayable returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| token | contract IERC20 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### advanceWeek

```solidity
function advanceWeek(uint256 _limit) external nonpayable
```

Indicate that (a) week(s) have passed and update running totalsReverts if called in week 0. Let it.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _limit | uint256 | Maximum number of weeks to process in one call |

### approve

```solidity
function approve(address to, uint256 tokenId) external nonpayable
```



*See {IERC721-approve}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| tokenId | uint256 | undefined |

### balanceOf

```solidity
function balanceOf(address owner) external view returns (uint256)
```



*See {IERC721-balanceOf}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### claimAndSendRewards

```solidity
function claimAndSendRewards(uint256 _tokenId, contract IERC20[] _rewardTokens) external nonpayable
```

claims all rewards distributed since token mint or last claim, and send them to another chain.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | The tokenId of the twTAP position |
| _rewardTokens | contract IERC20[] | The address of the reward token |

### claimRewards

```solidity
function claimRewards(uint256 _tokenId, address _to) external nonpayable
```

claims all rewards distributed since token mint or last claim.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | tokenId whose rewards to claim |
| _to | address | address to receive the rewards |

### claimable

```solidity
function claimable(uint256 _tokenId) external view returns (uint256[])
```

Amount currently claimable for each reward token



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256[] | undefined |

### claimed

```solidity
function claimed(uint256, uint256) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### clearCredits

```solidity
function clearCredits(bytes _payload) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _payload | bytes | undefined |

### creation

```solidity
function creation() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### currentWeek

```solidity
function currentWeek() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### distributeReward

```solidity
function distributeReward(uint256 _rewardTokenId, uint256 _amount) external nonpayable
```

distributes a reward among all tokens, weighted by voting powerThe reward gets allocated to all positions that have locked inthe current week. Fails, intentionally, if this number is zero.Total rewards cannot exceed 2^128 tokens.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardTokenId | uint256 | index of the reward in `rewardTokens` |
| _amount | uint256 | amount of reward token to distribute. |

### dstChainIdToBatchLimit

```solidity
function dstChainIdToBatchLimit(uint16) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### dstChainIdToTransferGas

```solidity
function dstChainIdToTransferGas(uint16) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### exitPosition

```solidity
function exitPosition(uint256 _tokenId) external nonpayable
```

Exit a twAML participation and delete the voting power if existing



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | The tokenId of the twTAP position |

### exitPositionAndSendTap

```solidity
function exitPositionAndSendTap(uint256 _tokenId) external nonpayable returns (uint256)
```

Exit a twAML participation and send the withdrawn TAP to tapOFT to send it to another chain.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | The tokenId of the twTAP position |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### failedMessages

```solidity
function failedMessages(uint16, bytes, uint64) external view returns (bytes32)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |
| _1 | bytes | undefined |
| _2 | uint64 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### forceResumeReceive

```solidity
function forceResumeReceive(uint16 _srcChainId, bytes _srcAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |

### getApproved

```solidity
function getApproved(uint256 tokenId) external view returns (address)
```



*See {IERC721-getApproved}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getConfig

```solidity
function getConfig(uint16 _version, uint16 _chainId, address, uint256 _configType) external view returns (bytes)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _version | uint16 | undefined |
| _chainId | uint16 | undefined |
| _2 | address | undefined |
| _configType | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | undefined |

### getParticipation

```solidity
function getParticipation(uint256 _tokenId) external view returns (struct Participation participant)
```

Return the participation of a token. Returns 0 votes for expired tokens.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| participant | Participation | undefined |

### getTrustedRemoteAddress

```solidity
function getTrustedRemoteAddress(uint16 _remoteChainId) external view returns (bytes)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _remoteChainId | uint16 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | undefined |

### isApprovedForAll

```solidity
function isApprovedForAll(address owner, address operator) external view returns (bool)
```



*See {IERC721-isApprovedForAll}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |
| operator | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### isTrustedRemote

```solidity
function isTrustedRemote(uint16 _srcChainId, bytes _srcAddress) external view returns (bool)
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

### lastProcessedWeek

```solidity
function lastProcessedWeek() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### lzEndpoint

```solidity
function lzEndpoint() external view returns (contract ILayerZeroEndpoint)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ILayerZeroEndpoint | undefined |

### lzReceive

```solidity
function lzReceive(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |
| _nonce | uint64 | undefined |
| _payload | bytes | undefined |

### minDstGasLookup

```solidity
function minDstGasLookup(uint16, uint16) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |
| _1 | uint16 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### minGasToTransferAndStore

```solidity
function minGasToTransferAndStore() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### mintedTWTap

```solidity
function mintedTWTap() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### name

```solidity
function name() external view returns (string)
```



*See {IERC721Metadata-name}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### nonblockingLzReceive

```solidity
function nonblockingLzReceive(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |
| _nonce | uint64 | undefined |
| _payload | bytes | undefined |

### nonces

```solidity
function nonces(address owner) external view returns (uint256)
```



*See {IERC20Permit-nonces}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### owner

```solidity
function owner() external view returns (address)
```



*Returns the address of the current owner.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### ownerOf

```solidity
function ownerOf(uint256 tokenId) external view returns (address)
```



*See {IERC721-ownerOf}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### participants

```solidity
function participants(uint256) external view returns (uint256 averageMagnitude, bool hasVotingPower, bool divergenceForce, bool tapReleased, uint56 expiry, uint88 tapAmount, uint24 multiplier, uint40 lastInactive, uint40 lastActive)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| averageMagnitude | uint256 | undefined |
| hasVotingPower | bool | undefined |
| divergenceForce | bool | undefined |
| tapReleased | bool | undefined |
| expiry | uint56 | undefined |
| tapAmount | uint88 | undefined |
| multiplier | uint24 | undefined |
| lastInactive | uint40 | undefined |
| lastActive | uint40 | undefined |

### participate

```solidity
function participate(address _participant, uint256 _amount, uint256 _duration) external nonpayable returns (uint256 tokenId)
```

Participate in twAMl voting and mint an oTAP position



#### Parameters

| Name | Type | Description |
|---|---|---|
| _participant | address | The address of the participant |
| _amount | uint256 | The amount of TAP to participate with |
| _duration | uint256 | The duration of the lock |

#### Returns

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

### payloadSizeLimitLookup

```solidity
function payloadSizeLimitLookup(uint16) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### permit

```solidity
function permit(address spender, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | undefined |
| tokenId | uint256 | undefined |
| deadline | uint256 | undefined |
| v | uint8 | undefined |
| r | bytes32 | undefined |
| s | bytes32 | undefined |

### precrime

```solidity
function precrime() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### releaseTap

```solidity
function releaseTap(uint256 _tokenId, address _to) external nonpayable
```

claims the TAP locked in a position whose votes have expired,and undoes the effect on the twAML calculations.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | tokenId whose locked TAP to claim |
| _to | address | address to receive the TAP |

### renounceOwnership

```solidity
function renounceOwnership() external nonpayable
```



*Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner. NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.*


### retryMessage

```solidity
function retryMessage(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |
| _nonce | uint64 | undefined |
| _payload | bytes | undefined |

### rewardTokenIndex

```solidity
function rewardTokenIndex(contract IERC20) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### rewardTokens

```solidity
function rewardTokens(uint256) external view returns (contract IERC20)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

### safeTransferFrom

```solidity
function safeTransferFrom(address from, address to, uint256 tokenId) external nonpayable
```



*See {IERC721-safeTransferFrom}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| tokenId | uint256 | undefined |

### safeTransferFrom

```solidity
function safeTransferFrom(address from, address to, uint256 tokenId, bytes data) external nonpayable
```



*See {IERC721-safeTransferFrom}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| tokenId | uint256 | undefined |
| data | bytes | undefined |

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

### setApprovalForAll

```solidity
function setApprovalForAll(address operator, bool approved) external nonpayable
```



*See {IERC721-setApprovalForAll}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| operator | address | undefined |
| approved | bool | undefined |

### setConfig

```solidity
function setConfig(uint16 _version, uint16 _chainId, uint256 _configType, bytes _config) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _version | uint16 | undefined |
| _chainId | uint16 | undefined |
| _configType | uint256 | undefined |
| _config | bytes | undefined |

### setDstChainIdToBatchLimit

```solidity
function setDstChainIdToBatchLimit(uint16 _dstChainId, uint256 _dstChainIdToBatchLimit) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _dstChainIdToBatchLimit | uint256 | undefined |

### setDstChainIdToTransferGas

```solidity
function setDstChainIdToTransferGas(uint16 _dstChainId, uint256 _dstChainIdToTransferGas) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _dstChainIdToTransferGas | uint256 | undefined |

### setMinDstGas

```solidity
function setMinDstGas(uint16 _dstChainId, uint16 _packetType, uint256 _minGas) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _packetType | uint16 | undefined |
| _minGas | uint256 | undefined |

### setMinGasToTransferAndStore

```solidity
function setMinGasToTransferAndStore(uint256 _minGasToTransferAndStore) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _minGasToTransferAndStore | uint256 | undefined |

### setPayloadSizeLimit

```solidity
function setPayloadSizeLimit(uint16 _dstChainId, uint256 _size) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _size | uint256 | undefined |

### setPrecrime

```solidity
function setPrecrime(address _precrime) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _precrime | address | undefined |

### setReceiveVersion

```solidity
function setReceiveVersion(uint16 _version) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _version | uint16 | undefined |

### setSendVersion

```solidity
function setSendVersion(uint16 _version) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _version | uint16 | undefined |

### setTrustedRemote

```solidity
function setTrustedRemote(uint16 _srcChainId, bytes _path) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _path | bytes | undefined |

### setTrustedRemoteAddress

```solidity
function setTrustedRemoteAddress(uint16 _remoteChainId, bytes _remoteAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _remoteChainId | uint16 | undefined |
| _remoteAddress | bytes | undefined |

### storedCredits

```solidity
function storedCredits(bytes32) external view returns (uint16 srcChainId, address toAddress, uint256 index, bool creditsRemain)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| srcChainId | uint16 | undefined |
| toAddress | address | undefined |
| index | uint256 | undefined |
| creditsRemain | bool | undefined |

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) external view returns (bool)
```



*See {IERC165-supportsInterface}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| interfaceId | bytes4 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### symbol

```solidity
function symbol() external view returns (string)
```



*See {IERC721Metadata-symbol}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### tapOFT

```solidity
function tapOFT() external view returns (contract TapOFT)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract TapOFT | undefined |

### tokenURI

```solidity
function tokenURI(uint256 tokenId) external view returns (string)
```



*See {IERC721Metadata-tokenURI}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 tokenId) external nonpayable
```



*See {IERC721-transferFrom}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| tokenId | uint256 | undefined |

### transferOwnership

```solidity
function transferOwnership(address newOwner) external nonpayable
```



*Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |

### trustedRemoteLookup

```solidity
function trustedRemoteLookup(uint16) external view returns (bytes)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | undefined |

### twAML

```solidity
function twAML() external view returns (uint256 totalParticipants, uint256 averageMagnitude, uint256 totalDeposited, uint256 cumulative)
```

===== TWAML ======




#### Returns

| Name | Type | Description |
|---|---|---|
| totalParticipants | uint256 | undefined |
| averageMagnitude | uint256 | undefined |
| totalDeposited | uint256 | undefined |
| cumulative | uint256 | undefined |

### weekTotals

```solidity
function weekTotals(uint256) external view returns (int256 netActiveVotes)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| netActiveVotes | int256 | undefined |



## Events

### AMLDivergence

```solidity
event AMLDivergence(uint256 cumulative, uint256 averageMagnitude, uint256 totalParticipants)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| cumulative  | uint256 | undefined |
| averageMagnitude  | uint256 | undefined |
| totalParticipants  | uint256 | undefined |

### Approval

```solidity
event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId)
```



*Emitted when `owner` enables `approved` to manage the `tokenId` token.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| approved `indexed` | address | undefined |
| tokenId `indexed` | uint256 | undefined |

### ApprovalForAll

```solidity
event ApprovalForAll(address indexed owner, address indexed operator, bool approved)
```



*Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| operator `indexed` | address | undefined |
| approved  | bool | undefined |

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

### ExitPosition

```solidity
event ExitPosition(uint256 indexed tokenId, uint256 amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId `indexed` | uint256 | undefined |
| amount  | uint256 | undefined |

### MessageFailed

```solidity
event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload, bytes _reason)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId  | uint16 | undefined |
| _srcAddress  | bytes | undefined |
| _nonce  | uint64 | undefined |
| _payload  | bytes | undefined |
| _reason  | bytes | undefined |

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |

### Participate

```solidity
event Participate(address indexed participant, uint256 tapAmount, uint256 multiplier)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| participant `indexed` | address | undefined |
| tapAmount  | uint256 | undefined |
| multiplier  | uint256 | undefined |

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

### RetryMessageSuccess

```solidity
event RetryMessageSuccess(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes32 _payloadHash)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId  | uint16 | undefined |
| _srcAddress  | bytes | undefined |
| _nonce  | uint64 | undefined |
| _payloadHash  | bytes32 | undefined |

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

### SetMinDstGas

```solidity
event SetMinDstGas(uint16 _dstChainId, uint16 _type, uint256 _minDstGas)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId  | uint16 | undefined |
| _type  | uint16 | undefined |
| _minDstGas  | uint256 | undefined |

### SetPrecrime

```solidity
event SetPrecrime(address precrime)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| precrime  | address | undefined |

### SetTrustedRemote

```solidity
event SetTrustedRemote(uint16 _remoteChainId, bytes _path)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _remoteChainId  | uint16 | undefined |
| _path  | bytes | undefined |

### SetTrustedRemoteAddress

```solidity
event SetTrustedRemoteAddress(uint16 _remoteChainId, bytes _remoteAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _remoteChainId  | uint16 | undefined |
| _remoteAddress  | bytes | undefined |

### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)
```



*Emitted when `tokenId` token is transferred from `from` to `to`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from `indexed` | address | undefined |
| to `indexed` | address | undefined |
| tokenId `indexed` | uint256 | undefined |




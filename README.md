All rights are reserved and the Tapioca codebase is not Open Source or Free. You cannot modify or redistribute this code without explicit written permission from the copyright holder (Tapioca Foundation & BoringCrypto [where applicable]).

# TapOFT 🍹 🤙

## Usage

To install Foundry:

```sh
curl -L https://foundry.paradigm.xyz | bash
```

This will download foundryup. To start Foundry, run:

```sh
foundryup
```

To clone the repo:

```sh
git clone https://github.com/Tapioca-DAO/tap-token.git && cd tap-token
```

## Install

To install this repository:

```bash
git submodule update --init

cd gitmodule/tapioca-periph
git submodule update --init gitmodule/permitc
cd -

yarn
forge build
```
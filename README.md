# THORSwap EVM Smart Contracts

> [!CAUTION] This repo comes with no guarantees
> This is not an archive of all contract versions. The current source code and what was deployed in the past may differ. This repo aims to centralize all smart contracts used in the THORSwap protocol, some import paths and dependencies have been adapted. Some contracts were audited, some were not audited, refer to `/audits` folder.

## Setup
Install dependencies with `yarn install`.

## Compiling
Compile contracts with `npx hardhat compile`.

## Deploying
Carefully set up `./scripts/deploy.ts` and run `npx hardhat run --network mainnet ./scripts/deploy.ts`.
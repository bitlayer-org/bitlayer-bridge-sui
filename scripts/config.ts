import { getAddress } from 'ethers'

export const COMMITTEE_MESSAGE_PREFIX = 'SUI_BRIDGE_MESSAGE'

export const MessageVersion = 1

export const config = {
  id: 16,
  package: () => process.env.PACKAGE || '',
  admin_cap: () => process.env.ADMIN_CAP_ID || '',
  bridge: () => process.env.BRIGE_OBJECT_ID || '',
  admin: () => process.env.ADMIN_PRIVATE_KEY || '',
  submitter: () => process.env.SUBMITTER || '',
  sbtc_coin_type: () => process.env.SBTC_COIN_TYPE || '',
  sbtc_metadata: () => process.env.SBTC_METADATA || '',
  sbtc_treasury: () => process.env.SBTC_TREASURY || '',
  upgrade_cap: () => process.env.UPGRADE_CAP_ID || '',
  committees: [
    {
      address: () => process.env.COMMITTEE1 || '',
      staked: 2222,
      isblacklisted: false,
    },
    {
      address: () => process.env.COMMITTEE2 || '',
      staked: 2222,
      isblacklisted: false,
    },
    {
      address: () => process.env.COMMITTEE3 || '',
      staked: 2222,
      isblacklisted: false,
    },
    {
      address: () => process.env.COMMITTEE4 || '',
      staked: 2222,
      isblacklisted: false,
    }
  ],
  supported_chains: {
    1: [
      {
        token_id: 1,
        fee_percentage: 0,
        bridge_amount: 0,
        supported: true,
        limit: 50 ** 8 * 1000,
        min_amount: 0.0001 ** 8 * 0.001,
      },
    ],
  },
}

export enum MessageType {
  TOKEN_TRANSFER = 0,
  COMMITTEE_BLOCKLIST = 1,
  EMERGENCY_OP = 2,
  UPDATE_BRIDGE_LIMIT = 3,
  UPDATE_ASSET_PRICE = 4,
  ADD_TOKENS_ON_SUI = 6,
  ADD_ROUTES_ON_SUI = 7,
  UPDATE_BRIDGE_MIN_AMOUNT = 8,
  UPDATE_BRIDGE_FEE_PERCENTAGE = 9,
}

import { SuiClient } from '@mysten/sui/dist/cjs/client'
import { Transaction } from '@mysten/sui/transactions'
import { config } from './config'
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519'
import { fromHex } from '@mysten/bcs'

export const withdrawTreasury = async (suiClient: SuiClient, tx: Transaction) => {
  const keypair = Ed25519Keypair.fromSecretKey(fromHex(config.admin()) || '')
  const receipt = process.env.RECEIPT_ADDRESS || ''

  tx.moveCall({
    target: `${config.package()}::bridge::withdraw_treasury`,
    typeArguments: [config.sbtc_coin_type()],
    arguments: [
      tx.object(config.bridge()),
      tx.object(config.admin_cap()),
      tx.pure.address(receipt),
    ],
  })

  const result = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer: keypair,
  })

  console.log('withdrawTreasury result:', result)
} 
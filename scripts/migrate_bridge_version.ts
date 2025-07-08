import { SuiClient } from '@mysten/sui/dist/cjs/client'
import { Transaction } from '@mysten/sui/transactions'
import { config } from './config'
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519'
import { fromHex } from '@mysten/bcs'

export const migrateBridgeVersion = async (suiClient: SuiClient, tx: Transaction) => {
  const keypair = Ed25519Keypair.fromSecretKey(fromHex(config.admin()) || '')

  tx.moveCall({
    target: `${config.package()}::bridge::migrate_bridge_version`,
    arguments: [
      tx.object(config.bridge()),
      tx.object(config.admin_cap())
    ],
  })

  const result = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer: keypair,
  })

  console.log('migrateBridgeVersion result:', result)
} 
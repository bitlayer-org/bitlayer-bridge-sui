import { getFullnodeUrl, SuiClient } from '@mysten/sui/client'
import { configDotenv } from 'dotenv'
import { executeAddRoutesOnSUI } from './execute_add_routes_on_sui'
import { Transaction } from '@mysten/sui/transactions'
import { updateSubmitter } from './update_submitter'
import { registerToken } from './register_token'
import { committeeRegistration } from './committee_registration'
import { createCommittee } from './create_committee'
import { executeAddTokensOnSUI } from './execute_add_tokens_on_sui'
import { executeUpdateBridgeLimit } from './execute_update_bridge_limit'
import { approveTokenTransferAndClaim } from './approve_token_transfer_and_cliam'
import { sendToken } from './send_token'
import { withdrawTreasury } from './withdraw_treasury'
import { transferAdminCap } from './transfer_admin_cap'
import { migrateAdminCapVersion } from './migrate_admin_cap_version'
import { migrateBridgeVersion } from './migrate_bridge_version'

configDotenv()

async function main() {
  const suiClient = new SuiClient({ url: getFullnodeUrl('testnet') })
  const tx = new Transaction()

  // 1. update submitter
  // await updateSubmitter(suiClient, tx)

  // 2. register token
  // await registerToken(suiClient, tx)

  // await withdrawTreasury(suiClient, tx)
  // await migrateAdminCapVersion(suiClient, tx)
  // await migrateBridgeVersion(suiClient, tx)

  // 3. register committee
  // await committeeRegistration(suiClient, tx)

  // 4. create committee
  // await createCommittee(suiClient, tx)

  // 5. execute add routes on sui
  // await executeAddRoutesOnSUI(suiClient, tx)

  // 6. execute add tokens on sui
  await executeAddTokensOnSUI(suiClient, tx)

  // 7. execute update bridge limit
  // await executeUpdateBridgeLimit(suiClient, tx)

  // 8. approve_token_transfer and claim
  //   await approveTokenTransferAndClaim(suiClient, tx)

  // 9. send token
  // await sendToken(suiClient, tx)

  // 10. transfer admin cap
  // await transferAdminCap(suiClient, tx)
}
main().catch((error) => {
  console.error(error)
})

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)
echo $SCRIPT_DIR
if [ -f $SCRIPT_DIR/.env ]; then
  source $SCRIPT_DIR/.env
else
  echo ".env file not found!"
  exit 1
fi

# Addresses
admin=$ADMIN

upgrade_cap_id=$UPGRADE_CAP_ID
admin_cap_id=$ADMIN_CAP_ID

# Clock
clock_id="0x6"

one=1e9

format_uint_func() {
    local input=$1  # amount
    local decimal=$2  # decimal
    local result=$(echo "$input * 10 ^ $decimal" | bc -l | awk '{print int($1)}')
    echo $result
}
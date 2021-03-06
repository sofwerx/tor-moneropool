#!/bin/bash
set -euf -o pipefail

if [ -z "${POOL_ADDRESS}" ]; then
  echo "ERROR: POOL_ADDRESS is not defined - need a monero address to pay miners from"
  exit 1
fi

cat <<EOF > /app/config.tmpl
/* Used for storage in redis so multiple coins can share the same redis instance. */
"coin": "monero",

/* Used for front-end display */
"symbol": "MRO",

"logging": {

    "console": {
        "level": "info",
        /* Gives console output useful colors. If you direct that output to a log file
           then disable this feature to avoid nasty characters in the file. */
        "colors": true
    }
},

/* Modular Pool Server */
"poolServer": {
    "enabled": true,

    /* Set to "auto" by default which will spawn one process/fork/worker for each CPU
       core in your system. Each of these workers will run a separate instance of your
       pool(s), and the kernel will load balance miners using these forks. Optionally,
       the 'forks' field can be a number for how many forks will be spawned. */
    "clusterForks": "auto",

    /* Address where block rewards go, and miner payments come from. */
    "poolAddress": "${POOL_ADDRESS}"

    /* Poll RPC daemons for new blocks every this many milliseconds. */
    "blockRefreshInterval": 1000,

    /* How many seconds until we consider a miner disconnected. */
    "minerTimeout": 900,

    "ports": [
        {
            "port": 3333, //Port for mining apps to connect to
            "difficulty": 100, //Initial difficulty miners are set to
            "desc": "Low end hardware" //Description of port
        },
        {
            "port": 5555,
            "difficulty": 2000,
            "desc": "Mid range hardware"
        },
        {
            "port": 7777,
            "difficulty": 10000,
            "desc": "High end hardware"
        }
    ],

    /* Variable difficulty is a feature that will automatically adjust difficulty for
       individual miners based on their hashrate in order to lower networking and CPU
       overhead. */
    "varDiff": {
        "minDiff": 2, //Minimum difficulty
        "maxDiff": 100000,
        "targetTime": 100, //Try to get 1 share per this many seconds
        "retargetTime": 30, //Check to see if we should retarget every this many seconds
        "variancePercent": 30, //Allow time to very this % from target without retargeting
        "maxJump": 100 //Limit diff percent increase/decrease in a single retargetting
    },

    /* Feature to trust share difficulties from miners which can
       significantly reduce CPU load. */
    "shareTrust": {
        "enabled": true,
        "min": 10, //Minimum percent probability for share hashing
        "stepDown": 3, //Increase trust probability % this much with each valid share
        "threshold": 10, //Amount of valid shares required before trusting begins
        "penalty": 30 //Upon breaking trust require this many valid share before trusting
    },

    /* If under low-diff share attack we can ban their IP to reduce system/network load. */
    "banning": {
        "enabled": true,
        "time": 600, //How many seconds to ban worker for
        "invalidPercent": 25, //What percent of invalid shares triggers ban
        "checkThreshold": 30 //Perform check when this many shares have been submitted
    },
    /* [Warning: several reports of this feature being broken. Proposed fix needs to be tested.] 
        Slush Mining is a reward calculation technique which disincentivizes pool hopping and rewards 
        'loyal' miners by valuing younger shares higher than older shares. Remember adjusting the weight!
        More about it here: https://mining.bitcoin.cz/help/#!/manual/rewards */
    "slushMining": {
        "enabled": false, //Enables slush mining. Recommended for pools catering to professional miners
        "weight": 300, //Defines how fast the score assigned to a share declines in time. The value should roughly be equivalent to the average round duration in seconds divided by 8. When deviating by too much numbers may get too high for JS.
        "lastBlockCheckRate": 1 //How often the pool checks the timestamp of the last block. Lower numbers increase load but raise precision of the share value
    }
},

/* Module that sends payments to miners according to their submitted shares. */
"payments": {
    "enabled": true,
    "interval": 600, //how often to run in seconds
    "maxAddresses": 50, //split up payments if sending to more than this many addresses
    "mixin": 3, //number of transactions yours is indistinguishable from
    "transferFee": 5000000000, //fee to pay for each transaction
    "minPayment": 100000000000, //miner balance required before sending payment
    "denomination": 100000000000 //truncate to this precision and store remainder
},

/* Module that monitors the submitted block maturities and manages rounds. Confirmed
   blocks mark the end of a round where workers' balances are increased in proportion
   to their shares. */
"blockUnlocker": {
    "enabled": true,
    "interval": 30, //how often to check block statuses in seconds

    /* Block depth required for a block to unlocked/mature. Found in daemon source as
       the variable CRYPTONOTE_MINED_MONEY_UNLOCK_WINDOW */
    "depth": 60,
    "poolFee": 0.0, //0.0% pool fee (2% total fee total including donations)
    "devDonation": 0.0, //0.0% donation to send to pool dev - only works with Monero
    "coreDevDonation": 0.0 //0.0% donation to send to core devs - only works with Monero
},

/* AJAX API used for front-end website. */
"api": {
    "enabled": true,
    "hashrateWindow": 600, //how many second worth of shares used to estimate hash rate
    "updateInterval": 3, //gather stats and broadcast every this many seconds
    "port": ${API_PORT:-8117},
    "blocks": 30, //amount of blocks to send at a time
    "payments": 30, //amount of payments to send at a time
    "password": "${ADMIN_PASSWORD:-password}" //password required for admin stats
},

/* Coin daemon connection details. */
"daemon": {
    "host": "127.0.0.1",
    "port": 18080
},

/* Wallet daemon connection details. */
"wallet": {
    "host": "127.0.0.1",
    "port": 18081
},

/* Redis connection into. */
"redis": {
    "host": "${REDIS_HOST:-moneroredis}",
    "port": ${REDIS_PORT:-6379},
    "auth": null //If set, client will run redis auth command on connect. Use for remote db
}
EOF

cp config_example.json config.json

exec node init.js

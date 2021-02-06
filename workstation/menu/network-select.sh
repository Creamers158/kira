#!/bin/bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

mkdir -p "$KIRA_CONFIGS"
TMP_GENESIS_PATH="/tmp/genesis.json"
LOCAL_GENESIS_PATH="$KIRA_CONFIGS/genesis.json"


while : ; do

    rm -fv "$TMP_GENESIS_PATH"
    NEW_NETWORK_NAME=""
    NEW_GENESIS_SOURCE=""
    NEW_NETWORK="false"

    SELECT="." && while [ "${SELECT,,}" != "n" ] && [ "${SELECT,,}" != "i" ] && [ "${SELECT,,}" != "s" ] ; do echo -en "\e[31;1mCreate [N]ew network, [I]mport genesis or use [S]napshoot: \e[0m\c" && read -d'' -s -n1 SELECT && echo ""; done

    if [ "${SELECT,,}" == "n" ] ; then # create new name
        CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
        while : ; do
            echo "INFO: New KIRA network will be created!"
            echo "INFO: Network name should have a format of <name>-<number>, e.g. mynetwork-1"
            echo -en "\e[31;1mProvide name of your NEW network (chain-id): \e[0m" && read NEW_NETWORK_NAME
        
            NEW_NETWORK_NAME="${NEW_NETWORK_NAME,,}"
            ARR=( $(echo "$NEW_NETWORK_NAME" | tr "-" "\n") ) && ARR_LEN=${#ARR[@]}
            [ ${#NEW_NETWORK_NAME} -gt 16 ] && echo -en "\e[33;1mWARNING: Network name can't be longer than 16 characters! \e[0m\c" && continue
            [ ${#NEW_NETWORK_NAME} -lt 3 ] && echo -en "\e[33;1mWARNING: Network name can't be shorter than 3 characters! \e[0m\c" && continue
            [ $ARR_LEN -ne 2 ] && echo -en "\e[33;1mWARNING: Network name must contain '-' character separatin name from id! \e[0m\c" && continue
            V1=${ARR[0]} && V2=${ARR[1]}
            [[ $V1 =~ [^a-zA-Z] ]] && echo "WARNING: Network name prefix must be a word (a-z)!"
            [[ $V2 != ?(-)+([0-9]) ]] && echo "WARNING: Network name suffix must be a number (0-9)!"
            break
        done
        NEW_NETWORK="true"
    elif [ "${SELECT,,}" == "s" ] ; then # import from snapshoot
        $KIRA_MANAGER/menu/snapshoot-select.sh
        set +e && source "/etc/profile" &>/dev/null && set -e # make sure to get new env's
        
        if [ -z "$KIRA_SNAP_PATH" ] || [ ! -f "$KIRA_SNAP_PATH" ] ; then
            CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
            echo "INFO: Snapshoot was not selected or '$KIRA_SNAP_PATH' file was not found"
            continue
        fi

        unzip -p $KIRA_SNAP_PATH genesis.json > "$TMP_GENESIS_PATH" || echo "" > "$TMP_GENESIS_PATH"
        NEW_NETWORK_NAME=$(jq -r .chain_id $TMP_GENESIS_PATH 2> /dev/null || echo "")
        [ -z "$NEW_NETWORK_NAME" ] && echoWarn "WARNING: Snapshoot file was not selected or does not contain a genesis file" && continue
    elif [ "${SELECT,,}" == "i" ] ; then # import from file or URL
        CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
        echo "INFO: Network genesis will be importend from the external resource"
        if [ -f "$LOCAL_GENESIS_PATH" ]; then 
            echoInfo "INFO: Default genesis source: $LOCAL_GENESIS_PATH"
            echoNErr "Provide file name, URL or click [ENTER] to choose default source: " && read NEW_GENESIS_SOURCE
        else
            echoNErr "Provide file name or URL to genesis source: " && read NEW_GENESIS_SOURCE
        fi
          
        [ -z "$NEW_GENESIS_SOURCE" ] && NEW_GENESIS_SOURCE=$LOCAL_GENESIS_PATH
         
        if [ -f "$NEW_GENESIS_SOURCE" ] ; then # if NEW_GENESIS_SOURCE is a file
            echo "INFO: Attempting to copy new genesis from '$NEW_GENESIS_SOURCE'"
            cp -a -f -v $NEW_GENESIS_SOURCE $TMP_GENESIS_PATH || echo "WARNING: Failed ot copy genesis from the source file '$NEW_GENESIS_SOURCE'"
        elif [ ! -z $NEW_GENESIS_SOURCE ] ; then # if NEW_GENESIS_SOURCE is not empty
            echo "INFO: Attempting to download new genesis from '$NEW_GENESIS_SOURCE'"
            wget "$NEW_GENESIS_SOURCE" -O $TMP_GENESIS_PATH || echo "WARNING: Download failed"
        else
            echo "WARNING: Genesis source was not provided"
            continue
        fi
          
        NEW_NETWORK_NAME=$(jq -r .result.genesis.chain_id $TMP_GENESIS_PATH 2> /dev/null 2> /dev/null || echo "")
        if [ ! -z "$NEW_NETWORK_NAME" ] && [ "$NEW_NETWORK_NAME" != "null" ] ; then
            jq -r .result.genesis "$TMP_GENESIS_PATH" > "/tmp/genesis.buffer.json"
            cp -a -f -v "/tmp/genesis.buffer.json" "$TMP_GENESIS_PATH"
        else
            NEW_NETWORK_NAME=$(jq -r .chain_id $TMP_GENESIS_PATH 2> /dev/null 2> /dev/null || echo "")
        fi

        if [ -z "$NEW_NETWORK_NAME" ] || [ "${NEW_NETWORK_NAME,,}" == "null" ] ; then
            echo "WARNING: Genesis file has invalid format, try diffrent source"
            continue
        fi
          
        echo "INFO: Success, genesis file was found and has a valid format"
        echo "INFO: $NEW_NETWORK_NAME network genesis checksum: $(sha256sum $TMP_GENESIS_PATH)"
        SELECT="." && while [ "${SELECT,,}" != "a" ] && [ "${SELECT,,}" != "r" ] && [ "${SELECT,,}" != "s" ] ; do echo -en "\e[31;1mChoose to [A]ccep or [R]eject the checksum: \e[0m\c" && read -d'' -s -n1 SELECT && echo ""; done
          
        if [ "${SELECT}" == "r" ] ; then
            echo "INFO: Genesis checksum was rejected, try diffrent source"
            continue
        fi
    else
        echo -en "\e[33;1mWARNING: Network name is not defined \e[0m\c" && echo ""
        continue
    fi

    echo "INFO: Network name will be set to '$NEW_NETWORK_NAME'"
    echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""
    
    if [ -f "$TMP_GENESIS_PATH" ] ; then # if fenesis was imported then replace locally
        echo "INFO: Backing up new genesis file..."
        rm -fv "$LOCAL_GENESIS_PATH"
        cp -a -f -v $TMP_GENESIS_PATH $LOCAL_GENESIS_PATH
    fi

    CDHelper text lineswap --insert="NETWORK_NAME=\"$NEW_NETWORK_NAME\"" --prefix="NETWORK_NAME=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="NEW_NETWORK=\"$NEW_NETWORK\"" --prefix="NEW_NETWORK=" --path=$ETC_PROFILE --append-if-found-not=True
    # if new network was created then we can delete public seeds from configuration
    [ "${NEW_NETWORK,,}" == "true" ] && rm -fv "$KIRA_CONFIGS/public_seeds"
    break
done

if [ "${INFRA_MODE,,}" == "validator" ] ; then
    echoInfo "INFO: Validator mode detected, last parameter to setup..."
    echoErr "IMORTANT: To prevent validator from double signing you MUST define a minimum block height below which new blocks will NOT be produced!"
    echoWarn "INFO: If you are creating a new network set minimum block height to 0 otherwise set it to the latest block height that the network can be at. If you do not set this parameter the latest height will be auto detected from the node you are currently connecting to, HOWEVER auto detection of the block height can't be 100% trused and in production environment a spacial care should be taken while setting this property!"
    
    while : ; do
        echoNErr "Define minimum block height: " && read VALIDATOR_MIN_HEIGHT
        ( [ -z "$VALIDATOR_MIN_HEIGHT" ] || [ -z "${VALIDATOR_MIN_HEIGHT##*[!0-9]*}" ] || [ $VALIDATOR_MIN_HEIGHT -lt 0 ] ) && continue
        break
    done

    echoInfo "INFO: Minimum block height your validator node will start prodicing new blocks at will be no lower than $VALIDATOR_MIN_HEIGHT"
    CDHelper text lineswap --insert="VALIDATOR_MIN_HEIGHT=\"$VALIDATOR_MIN_HEIGHT\"" --prefix="VALIDATOR_MIN_HEIGHT=" --path=$ETC_PROFILE --append-if-found-not=True
    echoErr "Press any key to continue or Ctrl+C to abort..." && read -n 1 -s && echo ""
else
    CDHelper text lineswap --insert="VALIDATOR_MIN_HEIGHT=\"0\"" --prefix="VALIDATOR_MIN_HEIGHT=" --path=$ETC_PROFILE --append-if-found-not=True
fi



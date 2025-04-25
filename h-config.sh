#!/bin/bash

process_user_config() {
    while IFS= read -r line; do
        [[ -z $line ]] && continue

        # Check if the line starts with nvtool and execute it using eval
        if [[ ${line:0:7} = "nvtool " ]]; then
            eval "$line"
        else
            # Remove spaces only from the beginning of the line
            line=$(echo "$line" | sed 's/^[[:space:]]*//')
            
            # Extract parameter and value using sed
            param=$(echo "$line" | sed -E 's/^"?([^"]*)"?\s*:.*/\1/')
            value=$(echo "$line" | sed -E 's/^"?[^"]*"?\s*:\s*//')

            # Store username for pool address construction
            if [[ "$param" == "wallet" ]]; then
                USERNAME=$value
                continue
            fi

            # Convert parameter to lowercase for cpuOnly check
            param_low=$(echo "$param" | tr '[:upper:]' '[:lower:]')

            # Check for CPU only mode
            if [[ "$param_low" == "cpuonly" && ("$value" == "true" || "$value" == "\"true\"" || "$value" == "yes" || "$value" == "\"yes\"") ]]; then
                CPU_ONLY=true
                continue
            fi

            # Store amountOfThreads parameter
            if [[ "$param" == "amountOfThreads" ]]; then
                AMOUNT_OF_THREADS=$value
                continue
            fi

            # Store trainer configuration
            if [[ "$param" == "trainer" ]]; then
                TRAINER_CONFIG=$line
                continue
            fi

            # Convert parameter to uppercase for other processing
            param_high=$(echo "$param" | tr '[:lower:]' '[:upper:]')

            # Perform replacements in the parameter
            modified_param=$(echo "$param_high" | sed '
                s/QUBICADDRESS/qubicAddress/g;
                s/CPUTHREADS/cpuThreads/g;
                s/ACCESSTOKEN/accessToken/g;
                s/ALLOWHWINFOCOLLECT/allowHwInfoCollect/g;
                s/HUGEPAGES/hugePages/g;
                s/ALIAS/alias/g;
                s/OVERWRITES/overwrites/g;
                s/IDLESETTINGS/Idling/g;
                s/PPS=/\"pps\": /g;
                s/USELIVECONNECTION/useLiveConnection/g;
                s/TRAINER/trainer/g;
            ')

            # Use modified parameter if changes were made
            [[ "$param" != "$modified_param" ]] && param=$modified_param

            # General processing for other parameters
            if [[ ! -z "$value" ]]; then
                if [[ "$param" == "overwrites" ]]; then
                    Settings=$(jq -s '.[0] * .[1]' <<< "$Settings {$line}")
                elif [[ "$param" == "Idling" ]]; then
                    Settings=$(jq --argjson Idling "$value" '
                        .Idling = $Idling | 
                        .Idling.preCommand = ($Idling.preCommand // null) |
                        .Idling.preCommandArguments = ($Idling.preCommandArguments // null) |
                        .Idling.command = ($Idling.command // null) |
                        .Idling.arguments = ($Idling.arguments // null) |
                        .Idling.postCommand = ($Idling.postCommand // null) |
                        .Idling.postCommandArguments = ($Idling.postCommandArguments // null)
                    ' <<< "$Settings")
                elif [[ "$param" == "pps" || "$param" == "useLiveConnection" ]]; then
                    if [[ "$value" == "true" || "$value" == "false" ]]; then
                        Settings=$(jq --argjson value "$value" '.[$param] = $value' <<< "$Settings")
                    else
                        echo "Invalid value for $param: $value. It must be 'true' or 'false'. Skipping this entry."
                    fi
                else
                    if [[ "$param" == "trainer.cpuThreads" ]]; then
                        Settings=$(jq --arg value "$value" '.trainer.cpuThreads = ($value | tonumber)' <<< "$Settings")
                    elif [[ "$param" == "trainer.gpu" ]]; then
                        Settings=$(jq --argjson value "$value" '.trainer.gpu = $value' <<< "$Settings")
                    elif [[ "$value" == "null" ]]; then
                        Settings=$(jq --arg param "$param" '.[$param] = null' <<< "$Settings")
                    elif [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                        Settings=$(jq --arg param "$param" --argjson value "$value" '.[$param] = ($value | tonumber)' <<< "$Settings")
                    else
                        Settings=$(jq --arg param "$param" --arg value "$value" '.[$param] = $value' <<< "$Settings")
                    fi
                fi
            fi
        fi
    done <<< "$CUSTOM_USER_CONFIG"
}

# Main script logic

# Processing global settings
GlobalSettings=$(jq -r '.ClientSettings' "/hive/miners/custom/$CUSTOM_NAME/appsettings_global.json" | envsubst)

# Initialize Settings
Settings="$GlobalSettings"

# Delete old settings
eval "rm -rf /hive/miners/custom/$CUSTOM_NAME/appsettings.json"

# Processing the template (alias)
if [[ ! -z $CUSTOM_TEMPLATE ]]; then
    Settings=$(jq --arg alias "$CUSTOM_TEMPLATE" '.alias = $alias' <<< "$Settings")
fi

# Processing user configuration
[[ ! -z $CUSTOM_USER_CONFIG ]] && process_user_config

# Adding poolAddress settings
if [[ ! -z $CUSTOM_URL ]]; then
    Settings=$(jq --arg poolAddress "$CUSTOM_URL/$USERNAME" '.poolAddress = $poolAddress' <<< "$Settings")
fi

# Check and modify Settings for hugePages parameter
if [[ $(jq '.hugePages' <<< "$Settings") != null ]]; then
    hugePages=$(jq -r '.hugePages' <<< "$Settings")
    if [[ ! -z $hugePages && $hugePages -gt 0 ]]; then
        eval "sysctl -w vm.nr_hugepages=$hugePages"
    fi
fi

# Store existing trainer settings that we want to preserve
if [[ ! -z "$TRAINER_CONFIG" ]]; then
    EXISTING_TRAINER=$(jq -r '.trainer' <<< "$Settings")
fi

# Configure trainer settings based on user input
Settings=$(jq 'del(.cpuOnly)' <<< "$Settings")

# Logic for CPU/GPU configuration while preserving existing trainer settings
if [[ "$CPU_ONLY" == "true" ]]; then
    if [[ ! -z "$AMOUNT_OF_THREADS" ]]; then
        # CPU only mode with specified threads
        Settings=$(jq --arg threads "$AMOUNT_OF_THREADS" '
            .trainer.cpu = true | 
            .trainer.gpu = false |
            .trainer.cpuThreads = ($threads | tonumber)
        ' <<< "$Settings")
    else
        # CPU only mode without threads specified
        Settings=$(jq '.trainer.cpu = true | .trainer.gpu = false' <<< "$Settings")
    fi
elif [[ ! -z "$AMOUNT_OF_THREADS" ]]; then
    # Both CPU and GPU, with specified threads
    Settings=$(jq --arg threads "$AMOUNT_OF_THREADS" '
        .trainer.cpu = true |
        .trainer.gpu = true |
        .trainer.cpuThreads = ($threads | tonumber)
    ' <<< "$Settings")
else
    # GPU only mode (default)
    Settings=$(jq '.trainer.cpu = false | .trainer.gpu = true' <<< "$Settings")
fi

# Apply trainer configuration if it exists
if [[ ! -z "$TRAINER_CONFIG" ]]; then
    # Convert any CUDA12 to CUDA before applying trainer configuration
    TRAINER_CONFIG=$(echo "$TRAINER_CONFIG" | sed 's/CUDA12/CUDA/g')
    Settings=$(jq -s '.[0] * .[1]' <<< "$Settings {$TRAINER_CONFIG}")
fi

# Create the final settings file
echo "{\"ClientSettings\":$Settings}" | jq . > "/hive/miners/custom/$CUSTOM_NAME/appsettings.json"

echo "Settings created successfully."

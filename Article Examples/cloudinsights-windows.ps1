 $DOWNLOAD_FROM = "https://$(Get-Variable domain -valueOnly)/rest/v1/integrations/raw/telegraf/releases/"
$DOWNLOAD_TO = (Get-Location).Path
$INSTALL_DIR = "c:\program files\telegraf\"
$CONFIG_DIR = "c:\program files\telegraf\telegraf.d"
$PKG_NAME = "telegraf-1.12.3_windows_amd64.zip"
$EXE_NAME = "telegraf.exe"

$COMPUTER_NAME=(Get-Childitem -path env:computername).Value
$HOSTIP=(Test-Connection $COMPUTER_NAME -count 1 | select Address,Ipv4Address).Ipv4Address
$NODE_UUID=(Get-CimInstance -Class Win32_ComputerSystemProduct).UUID
$NODE_OS="Microsoft Windows"

$DEFAULT_CONFIG = @"
    ##############################
    ## agent
    ##############################

    [global_tags]
      node_uuid = "$NODE_UUID"
      node_ip = "$HOSTIP"
      node_os = "$NODE_OS"

      ## USER-ACTION: In case of UI display name clash, disambiguate with 'name_prefix' and/or 'name_suffix' values.
      ## The tag(s) set here will be applied to all input plugins.  And, all Cloud Insights objects reported by this
      ## Telegraf agent will be prepended and appended by the name_prefix and name_suffix, respectively.  To override
      ## these values on a per-plugin-basis, modify the name_prefix and name_suffix values under the input plugin(s)
      ## accordingly.
      # name_prefix = "prefix"
      # name_suffix = "suffix"
      ## USER-ACTION: The default name field separator for the UI display name is '-'.  Override this separator with a different character, if desired.
      ## The tag set here will be applied to all input plugins.  And, all Cloud Insights objects reported by this
      ## Telegraf agent will have name_separator separating the individual fields used to construct the UI display name.
      ## To override this values on a per-plugin-basis, modify the name_separator under the input plugin(s) accordingly.
      # name_separator = "-"

      ## USER-ACTION: Provide cluster name
      ## If the Telegraf agent is installed and running on a node that is part of a Kubernetes cluster, uncomment the line
      ## below, and set the k8s_cluster tag value to the name of the Kubernetes cluster.
      # k8s_cluster = "<INSERT_K8S_CLUSTER_NAME>"

    [agent]
      ## Default data collection interval for all inputs
      interval = "10s"
      ## Rounds collection interval to 'interval'
      ## ie, if interval="10s" then always collect on :00, :10, :20, etc.
      round_interval = true

      ## Telegraf will send metrics to outputs in batches of at most
      ## metric_batch_size metrics.
      ## This controls the size of writes that Telegraf sends to output plugins.
      metric_batch_size = 1000

      ## For failed writes, telegraf will cache metric_buffer_limit metrics for each
      ## output, and will flush this buffer on a successful write. Oldest metrics
      ## are dropped first when this buffer fills.
      ## This buffer only fills when writes fail to output plugin(s).
      metric_buffer_limit = 10000

      ## Collection jitter is used to jitter the collection by a random amount.
      ## Each plugin will sleep for a random time within jitter before collecting.
      ## This can be used to avoid many plugins querying things like sysfs at the
      ## same time, which can have a measurable effect on the system.
      collection_jitter = "0s"

      ## Default flushing interval for all outputs. Maximum flush_interval will be
      ## flush_interval + flush_jitter
      flush_interval = "10s"
      ## Jitter the flush interval by a random amount. This is primarily to avoid
      ## large write spikes for users running a large number of telegraf instances.
      ## ie, a jitter of 5s and interval 10s means flushes will happen every 10-15s
      flush_jitter = "0s"

      ## By default or when set to "0s", precision will be set to the same
      ## timestamp order as the collection interval, with the maximum being 1s.
      ##   ie, when interval = "10s", precision will be "1s"
      ##       when interval = "250ms", precision will be "1ms"
      ## Precision will NOT be used for service inputs. It is up to each individual
      ## service input to set the timestamp at the appropriate precision.
      ## Valid time units are "ns", "us", "ms", "s".
      precision = ""

      ## Logging configuration:
      ## Run telegraf with debug log messages.
      debug = false
      ## Run telegraf in quiet mode (error log messages only).
      quiet = false
      ## Specify the log file name. The empty string means to log to stderr.
      logfile = ""

      ## Override default hostname, if empty use os.Hostname()
      hostname = ""
      ## If set to true, do no set the "host" tag in the telegraf agent.
      omit_hostname = false

    ##############################
    ## win_perf_counters
    ##############################

    [[inputs.win_perf_counters]]
      tagexclude = ["k8s_cluster"]

      [inputs.win_perf_counters.tags]
        CloudInsights = "true"

        ## USER-ACTION: In case of UI display name clash, disambiguate with 'name_prefix' and/or 'name_suffix' values.
        ## These tags can be set at the agent's global_tag level if the intent is to prepend and/or append the specified name_prefix
        ## and name_suffix, respectively, to all Cloud Insights objects reported by this Telegraf agent.
        # name_prefix = "prefix"
        # name_suffix = "suffix"
        ## USER-ACTION: The default name field separator for the UI display name is '-'.  Override this separator with a different character, if desired.
        ## This tag can be set at the agent's global_tag level if the intent is to use the same name field separator for all
        ## Cloud Insights objects reported by this Telegraf agent.
        # name_separator = "-"

        cloudinsights_win_perf_counters_conf_version = "1.0"

      [[inputs.win_perf_counters.object]]
        ## Processor usage, alternative to native, reports on a per core.
        ObjectName = "Processor"
        Instances = ["*"]
        Counters = [
          "% Idle Time",
          "% Interrupt Time",
          "% Privileged Time",
          "% User Time",
          "% Processor Time",
          "% DPC Time",
        ]
        Measurement = "win_cpu"

        ## Set to true to include _Total instance when querying for all (*).
        IncludeTotal=true

      [[inputs.win_perf_counters.object]]
        ObjectName = "PhysicalDisk"
        Instances = ["*"]
        Counters = [
          "Disk Read Bytes/sec",
          "Disk Write Bytes/sec",
          "Current Disk Queue Length",
          "Disk Reads/sec",
          "Disk Writes/sec",
          "% Disk Time",
          "% Disk Read Time",
          "% Disk Write Time",
        ]
        Measurement = "win_diskio"

      [[inputs.win_perf_counters.object]]
        ObjectName = "Network Interface"
        Instances = ["*"]
        Counters = [
          "Bytes Received/sec",
          "Bytes Sent/sec",
          "Packets Received/sec",
          "Packets Sent/sec",
          "Packets Received Discarded",
          "Packets Outbound Discarded",
          "Packets Received Errors",
          "Packets Outbound Errors",
        ]
        Measurement = "win_net"

      [[inputs.win_perf_counters.object]]
        ObjectName = "System"
        Counters = [
          "Context Switches/sec",
          "System Calls/sec",
          "Processes",
          "Processor Queue Length",
          "System Up Time",
        ]
        Instances = ["------"]
        Measurement = "win_system"

        ## Set to true to include _Total instance when querying for all (*).
        # IncludeTotal=false

      [[inputs.win_perf_counters.object]]
        ## Example query where the Instance portion must be removed to get data back,
        ## such as from the Memory object.
        ObjectName = "Memory"
        Counters = [
          "Available Bytes",
          "Cache Faults/sec",
          "Demand Zero Faults/sec",
          "Page Faults/sec",
          "Pages/sec",
          "Transition Faults/sec",
          "Pool Nonpaged Bytes",
          "Pool Paged Bytes",
          "Standby Cache Reserve Bytes",
          "Standby Cache Normal Priority Bytes",
          "Standby Cache Core Bytes",

        ]
        ## Use 6 x - to remove the Instance bit from the query.
        Instances = ["------"]
        Measurement = "win_mem"

        ## Set to true to include _Total instance when querying for all (*).
        # IncludeTotal=false

    [[outputs.http]]
      url = "https://hx7696.c01.cloudinsights.netapp.com/rest/v1/integrations/raw/telegraf"
      insecure_skip_verify = true
      data_format = "json"
      namepass = ["win_cpu"]
      tagexclude = ["CloudInsights", "objectname"]
      [outputs.http.headers]
        Content-Type = "application/json"
        X-CloudInsights-IntegrationAccessKey = "8bb90d87-51ef-4c33-b2c9-f5d8dda5866f"
        X-CloudInsights-IntegrationId = "win_cpu"
      [outputs.http.tagpass]
        CloudInsights = ["true"]
    [[outputs.http]]
      url = "https://hx7696.c01.cloudinsights.netapp.com/rest/v1/integrations/raw/telegraf"
      insecure_skip_verify = true
      data_format = "json"
      namepass = ["win_diskio"]
      tagexclude = ["CloudInsights", "objectname"]
      [outputs.http.headers]
        Content-Type = "application/json"
        X-CloudInsights-IntegrationAccessKey = "8bb90d87-51ef-4c33-b2c9-f5d8dda5866f"
        X-CloudInsights-IntegrationId = "win_diskio"
      [outputs.http.tagpass]
        CloudInsights = ["true"]
    [[outputs.http]]
      url = "https://hx7696.c01.cloudinsights.netapp.com/rest/v1/integrations/raw/telegraf"
      insecure_skip_verify = true
      data_format = "json"
      namepass = ["win_system"]
      tagexclude = ["CloudInsights", "objectname"]
      [outputs.http.headers]
        Content-Type = "application/json"
        X-CloudInsights-IntegrationAccessKey = "8bb90d87-51ef-4c33-b2c9-f5d8dda5866f"
        X-CloudInsights-IntegrationId = "win_system"
      [outputs.http.tagpass]
        CloudInsights = ["true"]
    [[outputs.http]]
      url = "https://hx7696.c01.cloudinsights.netapp.com/rest/v1/integrations/raw/telegraf"
      insecure_skip_verify = true
      data_format = "json"
      namepass = ["win_mem"]
      tagexclude = ["CloudInsights", "objectname"]
      [outputs.http.headers]
        Content-Type = "application/json"
        X-CloudInsights-IntegrationAccessKey = "8bb90d87-51ef-4c33-b2c9-f5d8dda5866f"
        X-CloudInsights-IntegrationId = "win_mem"
      [outputs.http.tagpass]
        CloudInsights = ["true"]
    [[outputs.http]]
      url = "https://hx7696.c01.cloudinsights.netapp.com/rest/v1/integrations/raw/telegraf"
      insecure_skip_verify = true
      data_format = "json"
      namepass = ["win_net"]
      tagexclude = ["CloudInsights", "objectname"]
      [outputs.http.headers]
        Content-Type = "application/json"
        X-CloudInsights-IntegrationAccessKey = "8bb90d87-51ef-4c33-b2c9-f5d8dda5866f"
        X-CloudInsights-IntegrationId = "win_net"
      [outputs.http.tagpass]
        CloudInsights = ["true"]

    ##############################
    ## disk
    ##############################

    [[inputs.disk]]
      ignore_fs = ["tmpfs", "devtmpfs", "devfs"]
      [inputs.disk.tags]
        CloudInsights = "true"

        ## USER-ACTION: In case of UI display name clash, disambiguate with 'name_prefix' and/or 'name_suffix' values.
        ## These tags can be set at the agent's global_tag level if the intent is to prepend and/or append the specified name_prefix
        ## and name_suffix, respectively, to all Cloud Insights objects reported by this Telegraf agent.
        # name_prefix = "prefix"
        # name_suffix = "suffix"
        ## USER-ACTION: The default name field separator for the UI display name is '-'.  Override this separator with a different character, if desired.
        ## This tag can be set at the agent's global_tag level if the intent is to use the same name field separator for all
        ## Cloud Insights objects reported by this Telegraf agent.
        # name_separator = "-"

        cloudinsights_disk_conf_version = "1.0"

    [[outputs.http]]
      url = "https://hx7696.c01.cloudinsights.netapp.com/rest/v1/integrations/raw/telegraf"
      insecure_skip_verify = true
      data_format = "json"
      namepass = ["disk"]
      tagexclude = ["CloudInsights"]
      [outputs.http.headers]
        Content-Type = "application/json"
        X-CloudInsights-IntegrationAccessKey = "8bb90d87-51ef-4c33-b2c9-f5d8dda5866f"
        X-CloudInsights-IntegrationId = "disk"
      [outputs.http.tagpass]
        CloudInsights = ["true"]

    ##############################
    ## mem
    ##############################

    [[inputs.mem]]
      [inputs.mem.tags]
        CloudInsights = "true"

        ## USER-ACTION: In case of UI display name clash, disambiguate with 'name_prefix' and/or 'name_suffix' values.
        ## These tags can be set at the agent's global_tag level if the intent is to prepend and/or append the specified name_prefix
        ## and name_suffix, respectively, to all Cloud Insights objects reported by this Telegraf agent.
        # name_prefix = "prefix"
        # name_suffix = "suffix"
        ## USER-ACTION: The default name field separator for the UI display name is '-'.  Override this separator with a different character, if desired.
        ## This tag can be set at the agent's global_tag level if the intent is to use the same name field separator for all
        ## Cloud Insights objects reported by this Telegraf agent.
        # name_separator = "-"

        cloudinsights_mem_conf_version = "1.0"

    [[outputs.http]]
      url = "https://hx7696.c01.cloudinsights.netapp.com/rest/v1/integrations/raw/telegraf"
      insecure_skip_verify = true
      data_format = "json"
      namepass = ["mem"]
      tagexclude = ["CloudInsights"]
      [outputs.http.headers]
        Content-Type = "application/json"
        X-CloudInsights-IntegrationAccessKey = "8bb90d87-51ef-4c33-b2c9-f5d8dda5866f"
        X-CloudInsights-IntegrationId = "mem"
      [outputs.http.tagpass]
        CloudInsights = ["true"]

    ##############################
    ## swap
    ##############################

    [[inputs.swap]]
      [inputs.swap.tags]
        CloudInsights = "true"

        ## USER-ACTION: In case of UI display name clash, disambiguate with 'name_prefix' and/or 'name_suffix' values.
        ## These tags can be set at the agent's global_tag level if the intent is to prepend and/or append the specified name_prefix
        ## and name_suffix, respectively, to all Cloud Insights objects reported by this Telegraf agent.
        # name_prefix = "prefix"
        # name_suffix = "suffix"
        ## USER-ACTION: The default name field separator for the UI display name is '-'.  Override this separator with a different character, if desired.
        ## This tag can be set at the agent's global_tag level if the intent is to use the same name field separator for all
        ## Cloud Insights objects reported by this Telegraf agent.
        # name_separator = "-"

        cloudinsights_swap_conf_version = "1.0"

    [[outputs.http]]
      url = "https://hx7696.c01.cloudinsights.netapp.com/rest/v1/integrations/raw/telegraf"
      insecure_skip_verify = true
      data_format = "json"
      namepass = ["swap"]
      tagexclude = ["CloudInsights"]
      [outputs.http.headers]
        Content-Type = "application/json"
        X-CloudInsights-IntegrationAccessKey = "8bb90d87-51ef-4c33-b2c9-f5d8dda5866f"
        X-CloudInsights-IntegrationId = "swap"
      [outputs.http.tagpass]
        CloudInsights = ["true"]

    ##############################
    ## system
    ##############################

    [[inputs.system]]
      [inputs.system.tags]
        CloudInsights = "true"

        ## USER-ACTION: In case of UI display name clash, disambiguate with 'name_prefix' and/or 'name_suffix' values.
        ## These tags can be set at the agent's global_tag level if the intent is to prepend and/or append the specified name_prefix
        ## and name_suffix, respectively, to all Cloud Insights objects reported by this Telegraf agent.
        # name_prefix = "prefix"
        # name_suffix = "suffix"
        ## USER-ACTION: The default name field separator for the UI display name is '-'.  Override this separator with a different character, if desired.
        ## This tag can be set at the agent's global_tag level if the intent is to use the same name field separator for all
        ## Cloud Insights objects reported by this Telegraf agent.
        # name_separator = "-"

        cloudinsights_system_conf_version = "1.0"

    [[outputs.http]]
      url = "https://hx7696.c01.cloudinsights.netapp.com/rest/v1/integrations/raw/telegraf"
      insecure_skip_verify = true
      data_format = "json"
      namepass = ["system"]
      tagexclude = ["CloudInsights"]
      fielddrop = ["uptime_format"]
      [outputs.http.headers]
        Content-Type = "application/json"
        X-CloudInsights-IntegrationAccessKey = "8bb90d87-51ef-4c33-b2c9-f5d8dda5866f"
        X-CloudInsights-IntegrationId = "system"
      [outputs.http.tagpass]
        CloudInsights = ["true"]
"@
$DEFAULT_CONFIG_FNAME = "${CONFIG_DIR}\cloudinsights-default.conf"
$DEFAULT_TELEGRAF_CONFIG_FILE = "${INSTALL_DIR}\telegraf.conf"

$telegraf_svc=(Get-Service telegraf -ErrorAction SilentlyContinue)

function Set-Default-Config {
  Write-Host "Setting default configuration..."
  "${DEFAULT_CONFIG}" | Out-File ${DEFAULT_CONFIG_FNAME} -encoding ascii
  if (!(Test-Path "${DEFAULT_CONFIG_FNAME}" -PathType Leaf)) {
    Write-Host "Failed to create default configuration file."
    exit 1
  }
}

function Wipe-Default-Telegraf-Config {
  Move-Item -Path "${DEFAULT_TELEGRAF_CONFIG_FILE}" -Destination "${DEFAULT_TELEGRAF_CONFIG_FILE}.bkup" -Force
  "" | Out-File ${DEFAULT_TELEGRAF_CONFIG_FILE} -encoding ascii
}

function Restart-Telegraf {
  Write-Host "Restarting Telegraf..."
  Invoke-Command -ScriptBlock {
      Stop-Service -Name telegraf -ErrorAction SilentlyContinue
      if (!(${telegraf_svc})) {
        & "${INSTALL_DIR}telegraf.exe" --service install --config "${INSTALL_DIR}\telegraf.conf" --config-directory "${CONFIG_DIR}"
      }
      Start-Service -Name telegraf
  }
}

if (${telegraf_svc}) {
  if (!(Test-Path "${INSTALL_DIR}${EXE_NAME}" -PathType Leaf)) {
    Write-Host "Telegraf service detected, but binary not in expected location."
    exit 1
  }
  Write-Host "Telegraf service detected.  Configuring installation..."
  if (!(Test-Path "${DEFAULT_CONFIG_FNAME}" -PathType Leaf)) {
    Move-Item -Path "${DEFAULT_CONFIG_FNAME}" -Destination "${DEFAULT_CONFIG_FNAME}.bkup" -Force
  }
  Set-Default-Config
  Restart-Telegraf
  exit 0
}

Write-Host "Downloading Telegraf to ${DOWNLOAD_TO}\${PKG_NAME}..."
$headers=@{}
$headers["Authorization"] = "Bearer $(Get-Variable token -valueOnly)"
Invoke-WebRequest -Uri "${DOWNLOAD_FROM}${PKG_NAME}" -Outfile "${DOWNLOAD_TO}\${PKG_NAME}" -Headers $headers -Method "GET"
if (!(Test-Path "${DOWNLOAD_TO}\${PKG_NAME}" -PathType Leaf)) {
  Write-Host "Failed to download Telegraf installation package: ${PKG_NAME}"
  exit 1
}

Write-Host "Installing Telegraf..."
Add-Type -assembly "system.io.compression.filesystem"
[io.compression.zipfile]::ExtractToDirectory("${DOWNLOAD_TO}\${PKG_NAME}", "c:\Program Files\")
New-Item -Path "${CONFIG_DIR}" -ItemType Directory -Force
if (!(Test-Path "${INSTALL_DIR}${EXE_NAME}" -PathType Leaf)) {
  Write-Host "Telegraf installation failed."
  exit 1
}

Set-Default-Config
Wipe-Default-Telegraf-Config
Restart-Telegraf 

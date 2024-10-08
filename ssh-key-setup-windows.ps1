# Function to check if the script is running as an administrator
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to check if the ssh-agent service is running
function Test-SSHAgentRunning {
    return (Get-Service ssh-agent -ErrorAction SilentlyContinue).Status -eq 'Running'
}

# Check if the ssh-agent service is running
$isSSHAgentRunning = Test-SSHAgentRunning

if (-not $isSSHAgentRunning) {
    # If the SSH agent is not running, check for Administrator privileges
    $isAdmin = Test-Administrator
    if (-not $isAdmin) {
        $proceed = Read-Host "The SSH agent service is not running, and the script is not running as an administrator. Do you want to proceed anyways? (y/n)"
        if ($proceed -ne 'y') {
            Write-Host "Exiting script. Please rerun as an administrator if you want the SSH agent to manage your new key."
            exit 1
        } else {
            Write-Host "Proceeding without SSH agent support."
        }
    } else {
        Write-Host "Starting the SSH agent..."
        Start-Service ssh-agent
    }
} else {
    Write-Host "SSH agent is already running."
}

# Get the current user's username
$username = $env:USERNAME
Write-Host "Username: $username"

# Check the hostname of the machine
$hostname = hostname
Write-Host "Hostname: $hostname"

# Retrieve the machine's UUID and trim any whitespace
$full_uuid = (wmic csproduct get UUID | findstr /v "UUID").Trim()
Write-Host "Full Machine UUID: $full_uuid"

# Trim the UUID to the last 6 characters for brevity
$short_uuid = $full_uuid[1].Substring(30,6)
Write-Host "Trimmed Machine UUID (Last 6 Characters): $short_uuid"

# Combine the hostname and trimmed UUID to create a unique identifier
$unique_id = "$username@$hostname`__$short_uuid"
Write-Host "Unique Identifier for SSH Key: $unique_id"

# Generate a new SSH key pair and prompt for a passphrase
# Default location: C:\Users\<YourUsername>\.ssh\id_rsa_<hostname>
$keypath = "$HOME\.ssh\id_rsa_$hostname"
$comment = "$unique_id"
Write-Host "Generating a new SSH key pair at: $keypath with comment: $comment"

# The ssh-keygen command will automatically prompt for a passphrase
ssh-keygen -t rsa -b 4096 -C $comment -f $keypath

if ($isSSHAgentRunning) {
    # Add the new SSH key to the agent if it's running
    Write-Host "Adding the new SSH key to the SSH agent..."
    ssh-add $keypath
} else {
    Write-Host "Skipping SSH key addition to the agent because the SSH agent is not running."
}

# Ensure the .ssh directory exists
$sshDir = "$HOME\.ssh"
if (-not (Test-Path $sshDir)) {
    New-Item -Path $sshDir -ItemType Directory
}

# Path to the SSH config file
$configFilePath = "$sshDir\config"

# Configuration block to add to the config file
$configContent = @"
Host github.com
  HostName github.com
  User git
  IdentityFile $keypath
"@

# Check if the config file exists
if (-not (Test-Path $configFilePath)) {
    # Create the config file and add the content
    Write-Host "Creating SSH config file and adding GitHub configuration..."
    $configContent | Out-File -FilePath $configFilePath -Encoding utf8
} else {
    # Check if the specific configuration block is already in the config file
    $existingConfig = Get-Content -Path $configFilePath -Raw
    if ($existingConfig.Contains($configContent)) {
        Write-Host "GitHub configuration already exists in SSH config file."
    } else {
        # Append the configuration to the existing config file
        Write-Host "Appending GitHub configuration to existing SSH config file..."
        Add-Content -Path $configFilePath -Value $configContent
    }
}

# Show the public key that was generated
$public_key = Get-Content "$keypath.pub"
Write-Host "`nPublic SSH Key Generated:"
Write-Host $public_key

# Copy the public key to the clipboard for easy access
$public_key | clip
Write-Host "`nThe public key has been copied to the clipboard."

# Display instructions for adding the key to your Git platform
Write-Host "`nInstructions: Please add the SSH key to your Git platform (e.g., GitHub, GitLab) under your SSH keys settings."

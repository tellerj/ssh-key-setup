# Function to check if the script is running as an administrator
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to check if the ssh-agent service is running
function Test-SSHAgentRunning {
    return (Get-Service ssh-agent -ErrorAction SilentlyContinue).Status -eq 'Running'
}

# Check for Administrator privileges
$isAdmin = Test-Administrator
$isSSHAgentRunning = Test-SSHAgentRunning


# if ($isSSHAgentRunning) {
#     continue
# } else {
#     if ($isAdmin) {
#         Write-Host "Starting ssh-agent service..."
#         Set-Service -Name ssh-agent -StartupType Automatic
#         Start-Service ssh-agent
#     } else {
#         $proceed = Read-Host "The ssh-agent service is not running, and the script cannot start it without admin privs. Proceed anyways? (Y/n)"
#         if ($proceed -eq 'n') {
#             Write-Host "Exiting script. Please rerun as an administrator if you want the SSH agent to manage your new key."
#             exit 1
#         } else {
#             Write-Host "Proceeding without ssh-agent support."
#         }
#     }
# }

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
    # Add the new SSH key to the agent
    Write-Host "Adding the new SSH key to the ssh-agent..."
    ssh-add $keypath
} else {
    Write-Host "Skipping SSH key addition to the agent because the SSH agent is not running."
}

# Show the public key that was generated
$public_key = Get-Content "$keypath.pub"
Write-Host "`nPublic SSH Key Generated:"
Write-Host $public_key

# Copy the public key to the clipboard for easy access
$public_key | clip
Write-Host "`nThe public key has been copied to the clipboard."

# Display instructions for adding the key to your Git platform
Write-Host "`nInstructions: Please add the following SSH key to your Git platform (e.g., GitHub, GitLab) under your SSH keys settings."

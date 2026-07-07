# Deploying the Viio Desktop Agent on macOS via Microsoft Intune

This guide describes how to roll out the Viio Desktop Agent to your macOS fleet
using Microsoft Intune, deploying the agent as a **macOS app (PKG)** with your
Viio customer key supplied through a pre-install script.

## How it works

The Viio agent package itself does not contain your customer key. The agent
reads its configuration from `/etc/viio.conf` on startup. During deployment,
a small pre-install script writes this file before the package is installed,
so the agent is fully configured the moment it starts.

## Prerequisites

- macOS devices enrolled in Intune (MDM).
- Your **Viio customer key**. You can find it in the Viio platform, or request
  it from your Viio contact.

## Step 1 — Download the agent package

Download the agent installer package:

```text
https://cdn.viio.io/desktop-agent/viio-agent-1.5.2.pkg
```

The package is signed by `Oveo ApS (895LF9A7K6)`, Viio's Apple Developer ID.

## Step 2 — Create the app in Intune

In the [Intune admin center](https://intune.microsoft.com), go to
**Apps → macOS → Add** and select the **macOS app (PKG)** app type.

<!-- ![Select the macOS app (PKG) app type](images/01-add-app-pkg.png) -->

Upload the `viio-agent-1.5.2.pkg` file you downloaded in Step 1.

<!-- ![Upload the Viio agent package](images/02-upload-pkg.png) -->

On the **App information** page, fill in the details, for example:

| Field     | Value              |
| --------- | ------------------ |
| Name      | Viio Desktop Agent |
| Publisher | Viio               |

<!-- ![App information page](images/03-app-information.png) -->

## Step 3 — Add the pre-install script with your customer key

On the **Scripts** step, set the following as the **Pre-install script**,
replacing `YOUR_CUSTOMER_KEY_HERE` with your Viio customer key:

```bash
#!/bin/bash
CUSTOMER_KEY="YOUR_CUSTOMER_KEY_HERE"
EMPLOYEE_EMAIL=""

echo "{\"CustomerKey\":\"$CUSTOMER_KEY\",\"EmployeeEmail\":\"$EMPLOYEE_EMAIL\"}" > /etc/viio.conf
chmod 400 /etc/viio.conf
chown root:wheel /etc/viio.conf
```

`EMPLOYEE_EMAIL` is optional and associates a device with a specific employee.
Leave it empty for a fleet-wide rollout; devices can be mapped to employees in
the Viio platform afterwards.

Optionally, add the following **Post-install script** so Intune reports a
failure if the agent did not start after installation:

```bash
#!/bin/bash
sleep 10
launchctl print system/io.viio.agent.metalauncher | grep -q "state = running"
```

<!-- ![Pre-install and post-install scripts](images/04-scripts.png) -->

## Step 4 — Detection rules and requirements

Leave the **Requirements** and **Detection rules** settings at their defaults.
Intune detects the app using the package IDs and version included in the
`.pkg` file.

<!-- ![Detection rules](images/05-detection-rules.png) -->

## Step 5 — Assign the app

On the **Assignments** step, add your target device group under **Required**.
The agent installs at the next Intune check-in.

<!-- ![Assignments](images/06-assignments.png) -->

## Step 6 — Verify the rollout

- In Intune, open the app and check **Device install status**.
- On a device, you can verify the agent is running with:

  ```sh
  sudo launchctl print system/io.viio.agent.metalauncher | grep state
  ```

  The output should contain `state = running`.

## Troubleshooting

If a device reports a failed installation, run Viio's troubleshooting script
on the device and share the output with [support@viio.io](mailto:support@viio.io):

```sh
bash -c "$(curl -L https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/macos.troubleshooting.sh)" &> result.txt
```

## Updating the agent

The Intune app pins a specific agent version. When Viio releases a new
package, upload the new `.pkg` to the same Intune app — devices upgrade
automatically at their next check-in.

# Full Attack Vector

This document show the entire attack vector from A to Z, without showing how individual steps are
achieved. This is supposed to help advance with the attack without requiring to do too much
exploration.


## TLDR

The attack vector looks as follows:

- RCE through application level vulnerability.
- ServiceAccount privilege exploitation to create pod that mounts host file system.
- Due to exec privileges missing, use a SSH daemon in target pod to gain access.
- If not landing on control-plane node, try to schedule the pod on control plane via affinty.
  - Achieved via exploration on agent node. Control-plane hostname is easily guessed.
- Use master Kubernetes configuration on control-plane to pwn cluster.
  - From here we could install a backdoor via static manifests to get persistent access.
  - From here we would also clean up our traces, such as:
    - deleting created resources during attack,
    - deleting audit logs,
    - modify installation to hide our future activity.
- Provide our vulnerable application cluster-admin rights to have simpler access.

## 

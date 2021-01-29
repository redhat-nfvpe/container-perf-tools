## Cyclictest

Start the cyclictest pod,
```
oc create -f pod_cyclictest.yaml
```

The duration of the cyclictest is defined by "DURATION" in the pod_cyclictest.yaml. To see  
the test progress and result,
```
oc logs cyclictest
```


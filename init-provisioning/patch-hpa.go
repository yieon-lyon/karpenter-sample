package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"k8s.io/api/autoscaling/v2"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	types "k8s.io/apimachinery/pkg/types"
)

type HPADetails struct {
    Name        string
    Namespace   string
    MinReplicas int32
    MaxReplicas int32
}
type PatchValue struct {
    Op      string `json:"op"`
    Path    string `json:"path"`
    Value   int32  `json:"value"`
}

func main() {
    userHomeDir, err := os.UserHomeDir()
    if err != nil {
        fmt.Printf("error getting user home dir: %v\n", err)
        os.Exit(1)
    }
    kubeConfigPath := filepath.Join(userHomeDir, ".kube", "config")
    fmt.Printf("Using kubeconfig: %s\n", kubeConfigPath)

    kubeConfig, err := clientcmd.BuildConfigFromFlags("", kubeConfigPath)
    if err != nil {
        fmt.Printf("Error getting kubernetes config: %v\n", err)
        os.Exit(1)
    }

    clientset, err := kubernetes.NewForConfig(kubeConfig)

    if err != nil {
        fmt.Printf("error getting kubernetes config: %v\n", err)
        os.Exit(1)
    }
    // An empty string returns all namespaces
//     namespace := ""

    jsonValue, err := os.ReadFile("hpa.json")
    if err != nil {
        fmt.Printf("error json file HPAs: %v\n", err)
        return
    }
    eventHPAs := []HPADetails{}
    json.Unmarshal(jsonValue, &eventHPAs)

    for _, hpa := range eventHPAs {
        /** Toggle Value +1 -> origin(+0) */
//         result, err := PatchHPAs(hpa.Namespace, clientset, hpa.Name, hpa.MinReplicas, hpa.MaxReplicas)
        result, err := PatchHPAs(hpa.Namespace, clientset, hpa.Name, hpa.MinReplicas+1, hpa.MaxReplicas+1)
        if err != nil {
            fmt.Printf("error patching HPA: %v\n", err)
            os.Exit(1)
        }
        fmt.Printf("patched HPA: %s \n", result.Name)
    }
}

func PatchHPAs(namespace string, client kubernetes.Interface, name string, min_replicas int32, max_replicas int32) (*v2.HorizontalPodAutoscaler, error) {
	fmt.Println("Patch Kubernetes HPA")
	payload := []PatchValue{{
        Op: "replace",
        Path: "/spec/maxReplicas",
        Value: max_replicas,
    }, {
       Op: "replace",
       Path: "/spec/minReplicas",
       Value: min_replicas,
    }}
	payloadBytes, _ := json.Marshal(payload)
	hpa, err := client.AutoscalingV2().HorizontalPodAutoscalers(namespace).Patch(context.Background(), name, types.JSONPatchType, payloadBytes, metav1.PatchOptions{})
	if err != nil {
		fmt.Printf("error patching HPAs: %v\n", err)
	}
	return hpa, err
}
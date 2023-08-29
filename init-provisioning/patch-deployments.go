package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"k8s.io/api/apps/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	types "k8s.io/apimachinery/pkg/types"
)

type DeploymentDetail struct {
    Name        string
    Namespace   string
    Replicas    int32
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
// 	namespace := ""

    jsonValue, err := os.ReadFile("deployments.json")
    if err != nil {
        fmt.Printf("error json file Deployments: %v\n", err)
        return
    }
    eventDeployments := []DeploymentDetail{}
    json.Unmarshal(jsonValue, &eventDeployments)

	for _, deploy := range eventDeployments {
        /** Toggle Value +1 -> origin(+0) */
//         result, err := PatchDeployment(deploy.Namespace, clientset, deploy.Name, deploy.Replicas)
        result, err := PatchDeployment(deploy.Namespace, clientset, deploy.Name, deploy.Replicas+1)
        if err != nil {
            fmt.Printf("error patching Deployment: %v\n", err)
            os.Exit(1)
        }
        fmt.Printf("patched Deployment: %s \n", result.Name)
	}
}

func PatchDeployment(namespace string, client kubernetes.Interface, name string, replicas int32) (*v1.Deployment, error) {
	fmt.Println("Patch Kubernetes Deployment")
	payload := []PatchValue{{
        Op: "replace",
        Path: "/spec/replicas",
        Value: replicas,
    }}
	payloadBytes, _ := json.Marshal(payload)
	deploy, err := client.AppsV1().Deployments(namespace).Patch(context.Background(), name, types.JSONPatchType, payloadBytes, metav1.PatchOptions{})
	if err != nil {
		fmt.Printf("error patching Deployment: %v\n", err)
	}
	return deploy, err
}
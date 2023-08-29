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
)

type DeploymentDetail struct {
    Name        string
    Namespace   string
    Replicas    int32
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
	namespace := ""
	Deployments, err := ListDeployments(namespace, clientset)
	if err != nil {
		fmt.Printf("error getting Deployments: %v\n", err)
		os.Exit(1)
	}

    eventDeployments := []DeploymentDetail{}
	for _, deploy := range Deployments.Items {
        if *deploy.Spec.Replicas == 1 {
            event := DeploymentDetail{
                Name: deploy.Name,
                Namespace: deploy.Namespace,
                Replicas: *deploy.Spec.Replicas,
            }
            eventDeployments = append(eventDeployments, event)
        }
	}

    b, err := json.MarshalIndent(eventDeployments, "", "  ")
    if err != nil {
        fmt.Printf("error json parse Deployments: %v\n", err)
        return
    }

    _ = os.WriteFile("deployments.json", b, 0644)
}

func ListDeployments(namespace string, client kubernetes.Interface) (*v1.DeploymentList, error) {
	fmt.Println("Get Kubernetes Deployments")
	deployments, err := client.AppsV1().Deployments(namespace).List(context.Background(), metav1.ListOptions{})
	if err != nil {
		fmt.Printf("error getting Deployments: %v\n", err)
	}
	return deployments, err
}
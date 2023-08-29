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
)

type HPADetails struct {
    Name        string
    Namespace   string
    MinReplicas int32
    MaxReplicas int32
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
	HPAs, err := ListHPAs(namespace, clientset)
	if err != nil {
		fmt.Printf("error getting HPAs: %v\n", err)
		os.Exit(1)
	}

    eventHPAs := []HPADetails{}
	for _, hpa := range HPAs.Items {
        if *hpa.Spec.MinReplicas == 1 {
            event := HPADetails{
                Name: hpa.Name,
                Namespace: hpa.Namespace,
                MinReplicas: *hpa.Spec.MinReplicas,
                MaxReplicas: hpa.Spec.MaxReplicas,
            }
            eventHPAs = append(eventHPAs, event)
        }
	}

    b, err := json.MarshalIndent(eventHPAs, "", "  ")
    if err != nil {
        fmt.Printf("error json parse HPAs: %v\n", err)
        return
    }

    _ = os.WriteFile("hpa.json", b, 0644)
}

func ListHPAs(namespace string, client kubernetes.Interface) (*v2.HorizontalPodAutoscalerList, error) {
	fmt.Println("Get Kubernetes HPAs")
	HPAs, err := client.AutoscalingV2().HorizontalPodAutoscalers(namespace).List(context.Background(), metav1.ListOptions{})
	if err != nil {
		fmt.Printf("error getting HPAs: %v\n", err)
	}
	return HPAs, err
}
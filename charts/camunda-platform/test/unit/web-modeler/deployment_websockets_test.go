// Copyright 2022 Camunda Services GmbH
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package web_modeler

import (
	"path/filepath"
	"strings"
	"testing"

	corev1 "k8s.io/api/core/v1"

	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/stretchr/testify/require"
	"github.com/stretchr/testify/suite"
	appsv1 "k8s.io/api/apps/v1"
)

type websocketsDeploymentTemplateTest struct {
	suite.Suite
	chartPath string
	release   string
	namespace string
	templates []string
}

func TestWebsocketsDeploymentTemplate(t *testing.T) {
	t.Parallel()

	chartPath, err := filepath.Abs("../../../")
	require.NoError(t, err)

	suite.Run(t, &websocketsDeploymentTemplateTest{
		chartPath: chartPath,
		release:   "camunda-platform-test",
		namespace: "camunda-platform-" + strings.ToLower(random.UniqueId()),
		templates: []string{"templates/web-modeler/deployment-websockets.yaml"},
	})
}

func (s *websocketsDeploymentTemplateTest) TestContainerSetPusherAppPathIfGlobalIngressEnabled() {
	// given
	options := &helm.Options{
		SetValues: map[string]string{
			"webModeler.enabled":                  "true",
			"webModeler.restapi.mail.fromAddress": "example@example.com",
			"webModeler.ingress.enabled":          "false",
			"webModeler.contextPath":              "/modeler",
			"global.ingress.enabled":              "true",
			"global.ingress.host":                 "c8.example.com",
			"global.ingress.tls.enabled":          "false",
		},
		KubectlOptions: k8s.NewKubectlOptions("", "", s.namespace),
	}

	// when
	output := helm.RenderTemplate(s.T(), options, s.chartPath, s.release, s.templates)
	var deployment appsv1.Deployment
	helm.UnmarshalK8SYaml(s.T(), output, &deployment)

	// then
	env := deployment.Spec.Template.Spec.Containers[0].Env
	s.Require().Contains(env, corev1.EnvVar{Name: "PUSHER_APP_PATH", Value: "/modeler-ws"})
}

func (s *websocketsDeploymentTemplateTest) TestContainerStartupProbe() {
	// given
	options := &helm.Options{
		SetValues: map[string]string{
			"webModeler.enabled":                         "true",
			"webModeler.restapi.mail.fromAddress":        "example@example.com",
			"webModeler.websockets.startupProbe.enabled": "true",
		},
		KubectlOptions: k8s.NewKubectlOptions("", "", s.namespace),
	}

	// when
	output := helm.RenderTemplate(s.T(), options, s.chartPath, s.release, s.templates)
	var deployment appsv1.Deployment
	helm.UnmarshalK8SYaml(s.T(), output, &deployment)

	// then
	probe := deployment.Spec.Template.Spec.Containers[0].StartupProbe

	s.Require().Equal("http", probe.TCPSocket.Port.StrVal)
}

func (s *websocketsDeploymentTemplateTest) TestContainerReadinessProbe() {
	// given
	options := &helm.Options{
		SetValues: map[string]string{
			"webModeler.enabled":                           "true",
			"webModeler.restapi.mail.fromAddress":          "example@example.com",
			"webModeler.websockets.readinessProbe.enabled": "true",
		},
		KubectlOptions: k8s.NewKubectlOptions("", "", s.namespace),
	}

	// when
	output := helm.RenderTemplate(s.T(), options, s.chartPath, s.release, s.templates)
	var deployment appsv1.Deployment
	helm.UnmarshalK8SYaml(s.T(), output, &deployment)

	// then
	probe := deployment.Spec.Template.Spec.Containers[0].ReadinessProbe

	s.Require().Equal("http", probe.TCPSocket.Port.StrVal)
}

func (s *websocketsDeploymentTemplateTest) TestContainerLivenessProbe() {
	// given
	options := &helm.Options{
		SetValues: map[string]string{
			"webModeler.enabled":                          "true",
			"webModeler.restapi.mail.fromAddress":         "example@example.com",
			"webModeler.websockets.livenessProbe.enabled": "true",
		},
		KubectlOptions: k8s.NewKubectlOptions("", "", s.namespace),
	}

	// when
	output := helm.RenderTemplate(s.T(), options, s.chartPath, s.release, s.templates)
	var deployment appsv1.Deployment
	helm.UnmarshalK8SYaml(s.T(), output, &deployment)

	// then
	probe := deployment.Spec.Template.Spec.Containers[0].LivenessProbe

	s.Require().Equal("http", probe.TCPSocket.Port.StrVal)
}

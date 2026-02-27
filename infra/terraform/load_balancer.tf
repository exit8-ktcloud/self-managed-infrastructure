# HTTPS Load Balancer + Cloud Armor
# Global External HTTPS Load Balancer with security policies

# Reserved Global Static IP for HTTPS Load Balancer
resource "google_compute_global_address" "lb_ip" {
  name    = "${var.lb_name}-ip"
  project = var.project_id
}

# Serverless NEGs or Instance Groups
# Using Instance Group for VM-based deployment

resource "google_compute_instance_group" "exit8_group" {
  name    = "${var.instance_name}-group"
  project = var.project_id
  zone    = var.zone

  instances = [google_compute_instance.exit8_vm.id]

  named_port {
    name = "http"
    port = 80
  }

  named_port {
    name = "https"
    port = 443
  }

  named_port {
    name = "http-alt"
    port = 8080
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Health Check
resource "google_compute_health_check" "exit8_hc" {
  name    = "${var.lb_name}-health-check"
  project = var.project_id

  http_health_check {
    port         = 80
    request_path = "/health"
    response     = "OK"
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

# Backend Service
resource "google_compute_backend_service" "exit8_backend" {
  name    = "${var.lb_name}-backend"
  project = var.project_id

  backend {
    group = google_compute_instance_group.exit8_group.id
  }

  health_checks           = [google_compute_health_check.exit8_hc.id]
  load_balancing_scheme   = "EXTERNAL_MANAGED"
  protocol                = "HTTP"
  port_name               = "http"
  enable_cdn              = false  # Enable if static content needs caching

  # Security policy (Cloud Armor)
  # ⚠️ 비활성화: GCP 무료/신규 계정은 SECURITY_POLICIES 쿼터가 0으로 제한됨.
  # 쿼터 증설 후 아래 주석을 해제하고, 아래 google_compute_security_policy 블록도 함께 활성화할 것.
  # GCP 콘솔 → IAM 및 관리자 → 할당량 → "SECURITY_POLICIES" 검색 → 증설 요청
  # security_policy = google_compute_security_policy.exit8_security.name

  # Connection draining
  connection_draining_timeout_sec = 300

  # Session affinity (optional)
  session_affinity = "NONE"

  # Timeout settings
  timeout_sec = 30
}

# URL Map (Routing Rules)
resource "google_compute_url_map" "exit8_urlmap" {
  name    = "${var.lb_name}-urlmap"
  project = var.project_id

  default_service = google_compute_backend_service.exit8_backend.id

  # Host rules can be added for multi-domain support
  # host_rule {
  #   hosts        = ["api.exit8.example.com"]
  #   path_matcher = "api"
  # }
}

# SSL Certificate (Self-managed or Google-managed)
# Using Google-managed for simplicity

resource "google_compute_managed_ssl_certificate" "exit8_cert" {
  name    = "${var.lb_name}-cert"
  project = var.project_id

  managed {
    domains = ["exit8.example.com"]  # Replace with your domain
  }

  lifecycle {
    create_before_destroy = true
  }
}

# HTTPS Target Proxy
resource "google_compute_target_https_proxy" "exit8_https_proxy" {
  name    = "${var.lb_name}-https-proxy"
  project = var.project_id

  url_map          = google_compute_url_map.exit8_urlmap.id
  ssl_certificates = [google_compute_managed_ssl_certificate.exit8_cert.id]

  # HSTS headers
  ssl_policy = google_compute_ssl_policy.exit8_ssl_policy.id
}

# HTTP Target Proxy (redirect to HTTPS)
resource "google_compute_target_http_proxy" "exit8_http_proxy" {
  name    = "${var.lb_name}-http-proxy"
  project = var.project_id

  url_map = google_compute_url_map.exit8_redirect.id
}

# URL Map for HTTP to HTTPS redirect
resource "google_compute_url_map" "exit8_redirect" {
  name    = "${var.lb_name}-redirect"
  project = var.project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"  # 301
    strip_query            = false
  }
}

# SSL Policy (Security hardening)
resource "google_compute_ssl_policy" "exit8_ssl_policy" {
  name    = "${var.lb_name}-ssl-policy"
  project = var.project_id

  profile            = "MODERN"  # TLS 1.2+ with modern ciphers
  min_tls_version    = "TLS_1_2"

  # Custom cipher selection if needed
  # custom_features = ["TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384", ...]
}

# Forwarding Rules (Global)
resource "google_compute_global_forwarding_rule" "exit8_https" {
  name    = "${var.lb_name}-https"
  project = var.project_id

  target     = google_compute_target_https_proxy.exit8_https_proxy.id
  ip_address = google_compute_global_address.lb_ip.address
  port_range = "443"

  load_balancing_scheme = "EXTERNAL_MANAGED"
}

resource "google_compute_global_forwarding_rule" "exit8_http" {
  name    = "${var.lb_name}-http"
  project = var.project_id

  target     = google_compute_target_http_proxy.exit8_http_proxy.id
  ip_address = google_compute_global_address.lb_ip.address
  port_range = "80"

  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# ============================================================================
# Cloud Armor Security Policy
# ⚠️ 현재 비활성화 상태 (GCP SECURITY_POLICIES 쿼터 0 제한)
#
# 활성화 방법:
#   1. GCP 콘솔 → IAM 및 관리자 → 할당량(Quotas) 메뉴로 이동
#   2. "SECURITY_POLICIES" 검색 후 증설 요청 (승인까지 수 시간~수일 소요)
#   3. 승인 완료 후 아래 블록 전체 주석 해제
#   4. backend_service의 security_policy 라인도 함께 주석 해제
# ============================================================================

# resource "google_compute_security_policy" "exit8_security" {
#   name    = "${var.lb_name}-security-policy"
#   project = var.project_id
#
#   # Default rule - allow all
#   rule {
#     action   = "allow"
#     priority = "2147483647"
#     match {
#       versioned_expr = "SRC_IPS_V1"
#       config {
#         src_ip_ranges = ["*"]
#       }
#     }
#     description = "Default allow rule"
#   }
#
#   # Block known bad IPs (can be updated)
#   # rule {
#   #   action   = "deny(403)"
#   #   priority = "1000"
#   #   match {
#   #     versioned_expr = "SRC_IPS_V1"
#   #     config {
#   #       src_ip_ranges = ["1.2.3.4/32"]
#   #     }
#   #   }
#   #   description = "Block known bad IPs"
#   # }
#
#   # ⚠️ 아래 WAF 룰은 SECURITY_POLICY_ADVANCED_RULES 쿼터도 추가로 필요.
#   # 쿼터 증설 후 주석 해제할 것.
#
#   # rule {
#   #   action   = "deny(403)"
#   #   priority = "2000"
#   #   match {
#   #     expr { expression = "evaluatePreconfiguredExpr('sqli-stable')" }
#   #   }
#   #   description = "Block SQL injection attempts"
#   # }
#
#   # rule {
#   #   action   = "deny(403)"
#   #   priority = "2001"
#   #   match {
#   #     expr { expression = "evaluatePreconfiguredExpr('xss-stable')" }
#   #   }
#   #   description = "Block XSS attempts"
#   # }
#
#   # rule {
#   #   action   = "deny(403)"
#   #   priority = "2002"
#   #   match {
#   #     expr { expression = "evaluatePreconfiguredExpr('lfi-stable')" }
#   #   }
#   #   description = "Block LFI attempts"
#   # }
#
#   # rule {
#   #   action   = "deny(403)"
#   #   priority = "2003"
#   #   match {
#   #     expr { expression = "evaluatePreconfiguredExpr('rfi-stable')" }
#   #   }
#   #   description = "Block RFI attempts"
#   # }
#
#   # rule {
#   #   action   = "deny(403)"
#   #   priority = "2004"
#   #   match {
#   #     expr { expression = "evaluatePreconfiguredExpr('php-stable')" }
#   #   }
#   #   description = "Block PHP injection attempts"
#   # }
# }


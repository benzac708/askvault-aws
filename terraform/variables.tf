variable "aws_region" {
  description = "Region emulated by LocalStack."
  type        = string
  default     = "us-east-1"
}

variable "aws_endpoint" {
  description = "LocalStack single API endpoint."
  type        = string
  default     = "http://localhost:4566"
}

variable "app_image" {
  description = "The AskVault image. The cloud repo never rebuilds it: the app repo ships immutable sha tags, and this is the one knob a promotion changes."
  type        = string
  default     = "ghcr.io/benzac708/askvault:main"
}

variable "corpus_bucket" {
  description = "Versioned corpus bucket (ingest source of truth)."
  type        = string
  default     = "askvault-corpus"
}

variable "records_table" {
  description = "DynamoDB table recording processed corpus documents."
  type        = string
  default     = "askvault-records"
}

variable "ingest_queue" {
  description = "Queue decoupling corpus events from the ingest path."
  type        = string
  default     = "askvault-ingest"
}

variable "llm_api_key" {
  description = "LLM provider key. In this repo it is a placeholder by design: production reads it from SSM Parameter Store, injected out of band."
  type        = string
  default     = "placeholder-not-a-real-key"
}
variable "emulated" {
  description = "True = LocalStack community (compute and load balancing are Pro-gated there). False = real AWS, where ECS + ALB + the full service wiring are included."
  type        = bool
  default     = true
}

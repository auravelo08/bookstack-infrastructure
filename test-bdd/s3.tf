resource "aws_s3_bucket" "db_dumps" {
  bucket        = "mon-unique-bucket-testdebdd-dumps" # ⚠️ Doit être unique au monde entier
  force_destroy = true                                # Permet le destroy même si le bucket contient des fichiers
  tags          = { Name = "db-dumps-storage" }
}

resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "EC2-S3-Dump-Permissions"
  role = aws_iam_role.rds_snapshot_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",    # Permet de télécharger le dump
          "s3:ListBucket"    # Permet de lister les fichiers du bucket
        ]
        Resource = [
          "${aws_s3_bucket.db_dumps.arn}",
          "${aws_s3_bucket.db_dumps.arn}/*"
        ]
      }
    ]
  })
}
#!/bin/bash
set -e

echo "=== VAST S3 Configuration Finder ==="
echo ""
echo "Based on VAST documentation, we need to:"
echo "1. Find the Virtual IPs (VIPs) configured for your VAST cluster"
echo "2. Check if S3 service is enabled"
echo "3. Test the correct S3 endpoint"
echo ""

echo "Please login to the VAST Web UI and check these locations:"
echo ""
echo "🌐 VAST Web UI: https://10.0.11.161"
echo "👤 Login: admin / 123456"
echo ""

echo "📍 Navigation Steps:"
echo "====================================="
echo ""
echo "1. LOGIN to VAST Web UI"
echo "   → Go to: https://10.0.11.161"
echo "   → Username: admin"
echo "   → Password: 123456"
echo ""

echo "2. FIND VIRTUAL IPs (VIPs)"
echo "   → In the Web UI menu, go to: Configuration > Virtual IPs"
echo "   → Look for VIPs that are configured for S3 traffic"
echo "   → Note down any IP addresses listed"
echo ""

echo "3. CHECK S3 SERVICE STATUS"
echo "   → Look for: Configuration > S3 or Services > S3"
echo "   → Check if S3 service is enabled/running"
echo "   → Note the service status and any endpoint information"
echo ""

echo "4. FIND S3 ENDPOINTS"
echo "   → Look for: S3 Endpoints or S3 Configuration"
echo "   → Check for any bucket endpoints or service URLs"
echo "   → Look for port configurations"
echo ""

echo "📝 WHAT TO LOOK FOR:"
echo "====================================="
echo ""
echo "VIP Information:"
echo "  • Virtual IP addresses (e.g., 10.0.11.x)"
echo "  • Which services are enabled on each VIP"
echo "  • S3 service status"
echo ""
echo "S3 Configuration:"
echo "  • S3 service enabled/disabled"
echo "  • Default buckets or endpoints"
echo "  • Port configuration (usually 80/443)"
echo "  • SSL/TLS settings"
echo ""

echo "🧪 QUICK TESTS YOU CAN RUN:"
echo "====================================="
echo ""

# Test if there are other VIPs in the subnet
echo "Testing for other potential VIPs in the 10.0.11.x range:"
ssh -o StrictHostKeyChecking=no -i ./vast-datalayer-poc-key.pem ubuntu@54.68.173.229 << 'EOF'
for ip in 160 162 163 164 165; do
    echo -n "  10.0.11.$ip: "
    timeout 2 ping -c 1 10.0.11.$ip >/dev/null 2>&1 && echo "✓ Responds" || echo "✗ No response"
done
EOF

echo ""
echo "🔧 ONCE YOU FIND THE INFO:"
echo "====================================="
echo ""
echo "Tell me:"
echo "1. The Virtual IP addresses you found"
echo "2. Whether S3 service is enabled"
echo "3. Any specific S3 endpoint URLs shown"
echo "4. Port numbers for S3 service"
echo ""
echo "I'll then update the TAMS configuration with the correct endpoint!"
echo ""

echo "🚀 Alternative: Let's try some educated guesses while you check:"

ssh -o StrictHostKeyChecking=no -i ./vast-datalayer-poc-key.pem ubuntu@54.68.173.229 << 'EOF'
echo ""
echo "Testing potential S3 subdomains/paths:"

# Test s3 subdomain approach
echo "1. Testing s3.10.0.11.161:"
timeout 5 curl -s -I http://s3.10.0.11.161/ 2>/dev/null && echo "   ✓ Responds" || echo "   ✗ No response"

# Test s3 path approach  
echo "2. Testing 10.0.11.161/s3:"
timeout 5 curl -s -I https://10.0.11.161/s3 -k 2>/dev/null && echo "   ✓ Responds" || echo "   ✗ No response"

# Test with different User-Agent (some systems respond differently to S3 clients)
echo "3. Testing with S3 User-Agent:"
timeout 5 curl -s -I -H "User-Agent: aws-cli/2.0.0 Python/3.8.0" https://10.0.11.161/ -k 2>/dev/null | grep -E "(Server|Content-Type)" || echo "   Same response as before"

# Test XML response (S3 typically returns XML)
echo "4. Testing for XML response:"
timeout 5 curl -s -H "Accept: application/xml" https://10.0.11.161/ -k 2>/dev/null | head -3 | grep -q "xml" && echo "   ✓ Got XML response" || echo "   ✗ No XML response"

EOF

echo ""
echo "Let me know what you find in the VAST Web UI! 🕵️"
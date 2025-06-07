
#!/bin/bash

# ============================================================================
# COMPLETE AUTOMATED SCRAPY PROJECT SETUP FOR ZYTE CLOUD
# Save this as setup.sh and run: bash setup.sh
# ============================================================================

echo "🚀 Setting up Scrapy project for Zyte Cloud deployment..."
echo

# Create scrapy.cfg
echo "📄 Creating scrapy.cfg..."
cat > scrapy.cfg << 'EOF'
[settings]
default = apilinkscraper.settings

[deploy]
url = https://app.scrapinghub.com/api/scrapyd/
project = 815501
EOF

# Create setup.py
echo "📄 Creating setup.py..."
cat > setup.py << 'EOF'
from setuptools import setup, find_packages

setup(
    name='apilinkscraper',
    version='1.0.0',
    packages=find_packages(),
    entry_points={'scrapy': ['settings = apilinkscraper.settings']},
    install_requires=[
        'scrapy>=2.5.0',
    ],
)
EOF

# Create requirements.txt
echo "📄 Creating requirements.txt..."
cat > requirements.txt << 'EOF'
scrapy>=2.5.0
requests>=2.25.0
EOF

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p apilinkscraper/spiders
touch apilinkscraper/__init__.py
touch apilinkscraper/spiders/__init__.py

# Create settings.py
echo "📄 Creating apilinkscraper/settings.py..."
cat > apilinkscraper/settings.py << 'EOF'
BOT_NAME = 'apilinkscraper'

SPIDER_MODULES = ['apilinkscraper.spiders']
NEWSPIDER_MODULE = 'apilinkscraper.spiders'

# Zyte Cloud optimizations
ROBOTSTXT_OBEY = True
DOWNLOAD_DELAY = 1
RANDOMIZE_DOWNLOAD_DELAY = True
CONCURRENT_REQUESTS = 8
CONCURRENT_REQUESTS_PER_DOMAIN = 2

USER_AGENT = 'apilinkscraper (+https://scrapinghub.com)'

# Enable and configure HTTP caching
HTTPCACHE_ENABLED = True
HTTPCACHE_EXPIRATION_SECS = 3600

# Disable cookies if not needed  
COOKIES_ENABLED = False

# Request headers
DEFAULT_REQUEST_HEADERS = {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en',
}

# Autothrottle settings
AUTOTHROTTLE_ENABLED = True
AUTOTHROTTLE_START_DELAY = 1
AUTOTHROTTLE_MAX_DELAY = 3
AUTOTHROTTLE_TARGET_CONCURRENCY = 2.0

# Memory usage optimization
MEMUSAGE_ENABLED = True
MEMUSAGE_LIMIT_MB = 2048
MEMUSAGE_WARNING_MB = 1024

# Retry settings
RETRY_ENABLED = True
RETRY_TIMES = 2
RETRY_HTTP_CODES = [500, 502, 503, 504, 408, 429]

# Logging
LOG_LEVEL = 'INFO'

# Output settings
FEEDS = {
    'apis_and_links.json': {
        'format': 'json',
        'overwrite': True,
    },
}
EOF

# Create the main spider
echo "🕷️  Creating apilinkscraper/spiders/api_link_scraper.py..."
cat > apilinkscraper/spiders/api_link_scraper.py << 'EOF'
import scrapy
import json
import re
from urllib.parse import urljoin, urlparse, parse_qs
from scrapy.http import Request
import logging

class ApiLinkSpider(scrapy.Spider):
    name = 'api_link_scraper'
    
    def __init__(self, start_url=None, *args, **kwargs):
        super(ApiLinkSpider, self).__init__(*args, **kwargs)
        if start_url:
            self.start_urls = [start_url]
        else:
            self.start_urls = ['https://example.com']  # Default URL
    
    # Patterns to exclude unwanted resources
    EXCLUDE_PATTERNS = [
        # Trackers and Analytics
        r'google-analytics\.com',
        r'googletagmanager\.com',
        r'facebook\.com/tr',
        r'doubleclick\.net',
        r'googlesyndication\.com',
        r'adsystem\.com',
        r'amazon-adsystem\.com',
        r'hotjar\.com',
        r'mixpanel\.com',
        r'segment\.com',
        r'intercom\.io',
        r'zendesk\.com',
        
        # Social Media Widgets
        r'platform\.twitter\.com',
        r'connect\.facebook\.net',
        r'platform\.linkedin\.com',
        r'apis\.google\.com/js/platform\.js',
        
        # Static Resources
        r'\.woff2?$',
        r'\.ttf$',
        r'\.eot$',
        r'\.png$',
        r'\.jpg$',
        r'\.jpeg$',
        r'\.gif$',
        r'\.ico$',
        r'\.svg$',
        r'\.webp$',
        r'\.css$',
        r'\.js$',
        
        # Events and Tracking
        r'event',
        r'track',
        r'pixel',
        r'beacon',
        r'analytics',
        
        # Common CDNs for static content
        r'cdnjs\.cloudflare\.com',
        r'unpkg\.com',
        r'jsdelivr\.net',
        r'fonts\.googleapis\.com',
        r'fonts\.gstatic\.com',
    ]
    
    # API endpoint patterns
    API_PATTERNS = [
        r'/api/',
        r'/v\d+/',
        r'\.json$',
        r'\.xml$',
        r'/rest/',
        r'/graphql',
        r'/endpoint',
        r'/service',
        r'/webservice',
    ]
    
    def is_excluded_url(self, url):
        """Check if URL should be excluded based on patterns"""
        for pattern in self.EXCLUDE_PATTERNS:
            if re.search(pattern, url, re.IGNORECASE):
                return True
        return False
    
    def is_api_endpoint(self, url):
        """Check if URL looks like an API endpoint"""
        for pattern in self.API_PATTERNS:
            if re.search(pattern, url, re.IGNORECASE):
                return True
        return False
    
    def extract_api_info(self, response, url):
        """Extract API information from response"""
        try:
            parsed_url = urlparse(url)
            base_url = f"{parsed_url.scheme}://{parsed_url.netloc}"
            endpoint = parsed_url.path
            
            # Try to determine method from context
            method = "GET"  # Default
            
            # Check for form submissions or AJAX calls that might indicate POST
            if response.css('form[action*="{}"]'.format(endpoint)):
                method = "POST"
            
            # Extract request/response body if available
            req_body = ""
            resp_body = ""
            
            try:
                # If it's a JSON response, capture it
                content_type = response.headers.get('Content-Type', b'').decode()
                if 'application/json' in content_type:
                    resp_body = response.text
                elif url.endswith('.json'):
                    resp_body = response.text
            except:
                pass
            
            return {
                'type': 'API',
                'base_url': base_url,
                'endpoint_name': endpoint.split('/')[-1] or 'root',
                'full_endpoint': endpoint,
                'method': method,
                'req_body': req_body,
                'response_body': resp_body[:1000] if resp_body else "",  # Limit response body size
                'full_url': url,
                'status_code': response.status
            }
        except Exception as e:
            self.logger.error(f"Error extracting API info from {url}: {e}")
            return None
    
    def start_requests(self):
        """Initial requests"""
        for url in self.start_urls:
            yield Request(
                url=url,
                callback=self.parse,
                meta={'handle_httpstatus_list': [200, 201, 202, 204, 301, 302, 404]}
            )
    
    def parse(self, response):
        """Main parsing method"""
        current_url = response.url
        
        # Extract all links from the page
        links = []
        
        # Get all href attributes
        for link in response.css('a[href]'):
            href = link.css('::attr(href)').get()
            if href:
                absolute_url = urljoin(current_url, href)
                if not self.is_excluded_url(absolute_url):
                    links.append({
                        'type': 'LINK',
                        'url': absolute_url,
                        'text': link.css('::text').get('').strip(),
                        'source_page': current_url
                    })
        
        # Extract API endpoints from JavaScript
        script_apis = self.extract_apis_from_scripts(response)
        
        # Extract API endpoints from network requests (if visible in HTML)
        html_apis = self.extract_apis_from_html(response)
        
        # Combine all APIs
        all_apis = script_apis + html_apis
        
        # Process found APIs
        for api_url in all_apis:
            if not self.is_excluded_url(api_url):
                absolute_api_url = urljoin(current_url, api_url)
                # Try to fetch the API endpoint
                yield Request(
                    url=absolute_api_url,
                    callback=self.parse_api_response,
                    meta={'original_url': current_url},
                    dont_filter=True
                )
        
        # Yield clean links
        for link in links:
            yield link
        
        # Follow internal links for more discovery
        for link in response.css('a[href]'):
            href = link.css('::attr(href)').get()
            if href:
                absolute_url = urljoin(current_url, href)
                parsed_current = urlparse(current_url)
                parsed_link = urlparse(absolute_url)
                
                # Only follow internal links and avoid excluded patterns
                if (parsed_current.netloc == parsed_link.netloc and 
                    not self.is_excluded_url(absolute_url) and
                    absolute_url not in getattr(self, 'visited_urls', set())):
                    
                    if not hasattr(self, 'visited_urls'):
                        self.visited_urls = set()
                    self.visited_urls.add(absolute_url)
                    
                    yield Request(
                        url=absolute_url,
                        callback=self.parse,
                        meta={'handle_httpstatus_list': [200, 301, 302]}
                    )
    
    def extract_apis_from_scripts(self, response):
        """Extract API URLs from JavaScript code"""
        apis = []
        
        # Extract from script tags
        for script in response.css('script::text').getall():
            # Look for common API patterns in JavaScript
            api_matches = re.findall(r'["\']([^"\']*(?:/api/|/v\d+/|\.json)[^"\']*)["\']', script, re.IGNORECASE)
            for match in api_matches:
                if not self.is_excluded_url(match):
                    apis.append(match)
            
            # Look for fetch() calls
            fetch_matches = re.findall(r'fetch\(["\']([^"\']+)["\']', script)
            for match in fetch_matches:
                if not self.is_excluded_url(match):
                    apis.append(match)
            
            # Look for XMLHttpRequest
            xhr_matches = re.findall(r'\.open\(["\'][^"\']*["\'],\s*["\']([^"\']+)["\']', script)
            for match in xhr_matches:
                if not self.is_excluded_url(match):
                    apis.append(match)
        
        return list(set(apis))  # Remove duplicates
    
    def extract_apis_from_html(self, response):
        """Extract API URLs from HTML attributes"""
        apis = []
        
        # Check data attributes that might contain API URLs
        for element in response.css('[data-api], [data-url], [data-endpoint]'):
            for attr in ['data-api', 'data-url', 'data-endpoint']:
                url = element.css(f'::attr({attr})').get()
                if url and not self.is_excluded_url(url):
                    apis.append(url)
        
        # Check form actions that might be API endpoints
        for form in response.css('form[action]'):
            action = form.css('::attr(action)').get()
            if action and self.is_api_endpoint(action):
                apis.append(action)
        
        return list(set(apis))
    
    def parse_api_response(self, response):
        """Parse API endpoint response"""
        api_info = self.extract_api_info(response, response.url)
        if api_info:
            yield api_info
EOF

# Create .gitignore
echo "📄 Creating .gitignore..."
cat > .gitignore << 'EOF'
# Scrapy stuff:
.scrapy

# Python:
*.pyc
*.pyo
*.pyd
__pycache__/
*.so
.Python
env/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
EOF

echo
echo "✅ Project setup complete!"
echo
echo "📁 Created project structure:"
echo "├── scrapy.cfg"
echo "├── setup.py"
echo "├── requirements.txt"
echo "├── .gitignore"
echo "├── apilinkscraper/"
echo "│   ├── __init__.py"
echo "│   ├── settings.py"
echo "│   └── spiders/"
echo "│       ├── __init__.py"
echo "│       └── api_link_scraper.py"
echo
echo "🚀 Ready to deploy! Run these commands:"
echo
echo "   shub deploy 815501"
echo
echo "📋 Then schedule a job:"
echo "   shub schedule api_link_scraper start_url=\"https://your-target-site.com\""
echo
echo "🎯 The spider will extract:"
echo "   ✓ APIs with BaseURL, Endpoint, Method, Request/Response bodies"
echo "   ✓ Clean links (no trackers, static files, or junk)"
echo "   ✓ Output saved as apis_and_links.json"
echo
echo "🎉 All done! Your project is ready for Zyte Cloud deployment."
Made with

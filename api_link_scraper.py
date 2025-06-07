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

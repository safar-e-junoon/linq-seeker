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

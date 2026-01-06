#!/usr/bin/env python3
"""
DSPy Program for Sentinel Dual-LLM Comparison

This module implements a DSPy program for comparing analysis outputs
from local (Ollama) and cloud (GPT-4o) LLMs.
"""

import dspy
from typing import Optional
import json
from datetime import datetime

# Configure DSPy with both LLMs
def configure_dspy(ollama_model: str = "llama3", cloud_model: str = "gpt-4o"):
    """Configure DSPy with both Ollama and cloud LLM backends."""
    
    # Configure Ollama LM
    ollama_lm = dspy.LM(
        model=ollama_model,
        api_base="http://localhost:11434/v1",
        api_key="ollama",  # Ollama doesn't require real API key
        model_type="openai"
    )
    
    # Configure cloud LM (using llm CLI or direct API)
    # For now, we'll use OpenAI-compatible interface
    cloud_lm = dspy.LM(
        model=cloud_model,
        api_provider="openai",  # Adjust based on your setup
        api_key=None  # Will use environment variable
    )
    
    return ollama_lm, cloud_lm


class SentinelAnalysis(dspy.Signature):
    """Analyze installation log snippet for errors and issues."""
    
    log_snippet: str = dspy.InputField(desc="Installation log snippet to analyze")
    
    severity: str = dspy.OutputField(desc="Severity level: INFO, WARN, ERROR, CRITICAL")
    category: str = dspy.OutputField(desc="Error category: Network, Permission, Dependency, etc.")
    pattern_matched: str = dspy.OutputField(desc="Specific error pattern detected")
    suggested_action: str = dspy.OutputField(desc="Recommended action to resolve")
    learning_candidate: bool = dspy.OutputField(desc="Should this be added to learning log? (true/false)")


class SentinelAnalyzer(dspy.Module):
    """DSPy module for analyzing installation logs."""
    
    def __init__(self, ollama_lm, cloud_lm):
        super().__init__()
        self.ollama_analyzer = dspy.ChainOfThought(SentinelAnalysis)
        self.cloud_analyzer = dspy.ChainOfThought(SentinelAnalysis)
        self.ollama_lm = ollama_lm
        self.cloud_lm = cloud_lm
    
    def forward(self, log_snippet: str, use_both: bool = True):
        """Analyze log snippet with one or both LLMs."""
        
        results = {}
        
        # Analyze with Ollama
        with dspy.context(lm=self.ollama_lm):
            ollama_result = self.ollama_analyzer(log_snippet=log_snippet)
            results['ollama'] = {
                'severity': ollama_result.severity,
                'category': ollama_result.category,
                'pattern_matched': ollama_result.pattern_matched,
                'suggested_action': ollama_result.suggested_action,
                'learning_candidate': ollama_result.learning_candidate
            }
        
        # Analyze with cloud LLM if requested
        if use_both:
            with dspy.context(lm=self.cloud_lm):
                cloud_result = self.cloud_analyzer(log_snippet=log_snippet)
                results['cloud'] = {
                    'severity': cloud_result.severity,
                    'category': cloud_result.category,
                    'pattern_matched': cloud_result.pattern_matched,
                    'suggested_action': cloud_result.suggested_action,
                    'learning_candidate': cloud_result.learning_candidate
                }
        
        return results


class LLMComparator(dspy.Module):
    """Compare outputs from two LLMs and identify differences."""
    
    def __init__(self):
        super().__init__()
        self.comparator = dspy.Predict(
            "ollama_analysis, cloud_analysis -> differences, agreement_score, recommendation"
        )
    
    def compare(self, ollama_analysis: dict, cloud_analysis: dict) -> dict:
        """Compare two analysis results and return differences."""
        
        # Convert to JSON strings for comparison
        ollama_str = json.dumps(ollama_analysis, indent=2)
        cloud_str = json.dumps(cloud_analysis, indent=2)
        
        comparison = self.comparator(
            ollama_analysis=ollama_str,
            cloud_analysis=cloud_str
        )
        
        return {
            'differences': comparison.differences,
            'agreement_score': comparison.agreement_score,
            'recommendation': comparison.recommendation,
            'timestamp': datetime.utcnow().isoformat()
        }


def analyze_with_dual_llm(
    log_snippet: str,
    ollama_model: str = "llama3",
    cloud_model: str = "gpt-4o",
    compare: bool = True
) -> dict:
    """
    Analyze log snippet with both Ollama and cloud LLM, optionally comparing results.
    
    Args:
        log_snippet: Log content to analyze
        ollama_model: Ollama model name
        cloud_model: Cloud LLM model name
        compare: Whether to compare the two analyses
    
    Returns:
        Dictionary with analysis results and optional comparison
    """
    
    # Configure DSPy
    ollama_lm, cloud_lm = configure_dspy(ollama_model, cloud_model)
    
    # Create analyzer
    analyzer = SentinelAnalyzer(ollama_lm, cloud_lm)
    
    # Analyze
    results = analyzer(log_snippet, use_both=True)
    
    # Compare if requested
    if compare and 'ollama' in results and 'cloud' in results:
        comparator = LLMComparator()
        comparison = comparator.compare(results['ollama'], results['cloud'])
        results['comparison'] = comparison
    
    return results


if __name__ == "__main__":
    # Example usage
    sample_log = """
    Error: Failed to install package
    Warning: Connection timeout
    """
    
    result = analyze_with_dual_llm(sample_log, compare=True)
    print(json.dumps(result, indent=2))


#!/usr/bin/env python3
"""
Deepeval Evaluator for Sentinel Analysis Quality

This module implements deepeval evaluation metrics for assessing
the quality of sentinel LLM analysis.
"""

from deepeval import evaluate
from deepeval.metrics import (
    RelevanceMetric,
    HallucinationMetric,
    AnswerRelevancyMetric,
    FaithfulnessMetric
)
from deepeval.test_case import LLMTestCase
from typing import Dict, List, Optional
import json
from datetime import datetime


class SentinelEvaluator:
    """Evaluator for sentinel analysis quality."""
    
    def __init__(self):
        self.metrics = {
            'relevance': RelevanceMetric(threshold=0.7),
            'hallucination': HallucinationMetric(threshold=0.5),
            'answer_relevancy': AnswerRelevancyMetric(threshold=0.7),
            'faithfulness': FaithfulnessMetric(threshold=0.7)
        }
        self.test_cases: List[LLMTestCase] = []
    
    def create_test_case(
        self,
        input_text: str,
        actual_output: str,
        expected_output: Optional[str] = None,
        context: Optional[str] = None
    ) -> LLMTestCase:
        """Create a test case for evaluation."""
        
        return LLMTestCase(
            input=input_text,
            actual_output=actual_output,
            expected_output=expected_output,
            context=context
        )
    
    def evaluate_analysis(
        self,
        log_snippet: str,
        analysis: str,
        expected_severity: Optional[str] = None
    ) -> Dict:
        """Evaluate a single analysis result."""
        
        test_case = self.create_test_case(
            input_text=log_snippet,
            actual_output=analysis,
            expected_output=expected_severity,
            context="Installation log analysis"
        )
        
        results = {}
        
        # Evaluate with each metric
        for metric_name, metric in self.metrics.items():
            try:
                metric.measure(test_case)
                results[metric_name] = {
                    'score': metric.score,
                    'threshold': metric.threshold,
                    'passed': metric.score >= metric.threshold,
                    'reason': metric.reason if hasattr(metric, 'reason') else None
                }
            except Exception as e:
                results[metric_name] = {
                    'error': str(e),
                    'passed': False
                }
        
        return {
            'test_case': test_case,
            'results': results,
            'timestamp': datetime.utcnow().isoformat()
        }
    
    def evaluate_comparison(
        self,
        log_snippet: str,
        ollama_analysis: str,
        cloud_analysis: str
    ) -> Dict:
        """Evaluate and compare two analyses."""
        
        ollama_eval = self.evaluate_analysis(log_snippet, ollama_analysis)
        cloud_eval = self.evaluate_analysis(log_snippet, cloud_analysis)
        
        # Compare scores
        comparison = {}
        for metric_name in self.metrics.keys():
            ollama_score = ollama_eval['results'].get(metric_name, {}).get('score', 0)
            cloud_score = cloud_eval['results'].get(metric_name, {}).get('score', 0)
            
            comparison[metric_name] = {
                'ollama': ollama_score,
                'cloud': cloud_score,
                'difference': cloud_score - ollama_score,
                'better': 'cloud' if cloud_score > ollama_score else 'ollama'
            }
        
        return {
            'ollama_evaluation': ollama_eval,
            'cloud_evaluation': cloud_eval,
            'comparison': comparison,
            'timestamp': datetime.utcnow().isoformat()
        }
    
    def batch_evaluate(self, test_cases: List[LLMTestCase]) -> Dict:
        """Evaluate a batch of test cases."""
        
        results = []
        for test_case in test_cases:
            eval_result = {}
            for metric_name, metric in self.metrics.items():
                try:
                    metric.measure(test_case)
                    eval_result[metric_name] = {
                        'score': metric.score,
                        'passed': metric.score >= metric.threshold
                    }
                except Exception as e:
                    eval_result[metric_name] = {'error': str(e)}
            results.append({
                'test_case': test_case,
                'results': eval_result
            })
        
        # Calculate aggregate scores
        aggregate = {}
        for metric_name in self.metrics.keys():
            scores = [
                r['results'].get(metric_name, {}).get('score', 0)
                for r in results
                if 'score' in r['results'].get(metric_name, {})
            ]
            if scores:
                aggregate[metric_name] = {
                    'mean': sum(scores) / len(scores),
                    'min': min(scores),
                    'max': max(scores),
                    'count': len(scores)
                }
        
        return {
            'individual_results': results,
            'aggregate_scores': aggregate,
            'timestamp': datetime.utcnow().isoformat()
        }


def evaluate_sentinel_analysis(
    log_snippet: str,
    analysis: str,
    expected_severity: Optional[str] = None
) -> Dict:
    """
    Convenience function to evaluate a single analysis.
    
    Args:
        log_snippet: Original log content
        analysis: LLM analysis output
        expected_severity: Expected severity level (if known)
    
    Returns:
        Evaluation results dictionary
    """
    
    evaluator = SentinelEvaluator()
    return evaluator.evaluate_analysis(log_snippet, analysis, expected_severity)


def evaluate_dual_analysis(
    log_snippet: str,
    ollama_analysis: str,
    cloud_analysis: str
) -> Dict:
    """
    Convenience function to evaluate and compare dual analyses.
    
    Args:
        log_snippet: Original log content
        ollama_analysis: Analysis from Ollama
        cloud_analysis: Analysis from cloud LLM
    
    Returns:
        Comparison evaluation results
    """
    
    evaluator = SentinelEvaluator()
    return evaluator.evaluate_comparison(log_snippet, ollama_analysis, cloud_analysis)


if __name__ == "__main__":
    # Example usage
    sample_log = "Error: Failed to install package"
    sample_analysis = "Severity: ERROR\nCategory: Installation\nPattern: Failed to install"
    
    result = evaluate_sentinel_analysis(sample_log, sample_analysis, "ERROR")
    print(json.dumps(result, indent=2))


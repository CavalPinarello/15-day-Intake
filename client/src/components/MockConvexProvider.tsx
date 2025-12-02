"use client";

import { createContext, useContext, useState, ReactNode } from 'react';

// Mock implementation for testing without live Convex
interface MockConvexContextType {
  useQuery: (api: any, args: any) => any;
  useMutation: (api: any) => any;
}

const MockConvexContext = createContext<MockConvexContextType | null>(null);

// Mock data for testing
const mockQuestions = [
  {
    question_id: "1",
    question_text: "On a scale of 1-10, how would you rate your overall sleep quality over the past month?",
    help_text: "1 = Very Poor, 10 = Excellent",
    answer_format: "slider_scale",
    format_config: JSON.stringify({
      min: 1,
      max: 10,
      step: 1,
      labels: { min: "Very Poor", max: "Excellent" },
      showQuickSelect: true
    }),
    validation_rules: JSON.stringify([]),
    conditional_logic: undefined,
    required: true,
    order_index: 1,
    estimated_time_seconds: 30
  },
  {
    question_id: "2", 
    question_text: "What is your typical bedtime?",
    help_text: "Select the time you usually go to bed on weekdays",
    answer_format: "time_picker",
    format_config: JSON.stringify({
      format: "HH:MM",
      allowCrossMidnight: true
    }),
    validation_rules: JSON.stringify([]),
    conditional_logic: undefined,
    required: true,
    order_index: 2,
    estimated_time_seconds: 45
  },
  {
    question_id: "3",
    question_text: "Do you currently have trouble falling asleep?",
    help_text: "Think about your experience over the past 2 weeks",
    answer_format: "single_select_chips",
    format_config: JSON.stringify({
      options: [
        { value: "never", label: "Never" },
        { value: "rarely", label: "Rarely" },
        { value: "sometimes", label: "Sometimes" }, 
        { value: "often", label: "Often" },
        { value: "always", label: "Always" }
      ],
      layout: "vertical"
    }),
    validation_rules: JSON.stringify([]),
    conditional_logic: undefined,
    required: true,
    order_index: 3,
    estimated_time_seconds: 60
  }
];

const mockDaySummary = {
  dayNumber: 1,
  estimated_time_seconds: 2520, // 42 minutes
  modules: [
    { module_id: "social_core", name: "Social Demographics" },
    { module_id: "metabolic_core", name: "Metabolic Health" },
    { module_id: "sleep_quality_core", name: "Sleep Quality Assessment" }
  ]
};

export function MockConvexProvider({ children }: { children: ReactNode }) {
  const [responses] = useState(new Map());

  const mockUseQuery = (api: any, args: any) => {
    // Simulate loading delay
    if (api.toString().includes('getQuestionsByDay')) {
      return mockQuestions;
    }
    if (api.toString().includes('getDaySummary')) {
      return mockDaySummary;
    }
    if (api.toString().includes('getUserDayProgress')) {
      return { completed: 0, total: 3 };
    }
    return null;
  };

  const mockUseMutation = (api: any) => {
    return async (args: any) => {
      console.log('Mock mutation called:', api.toString(), args);
      // Simulate successful response
      return { success: true };
    };
  };

  const contextValue: MockConvexContextType = {
    useQuery: mockUseQuery,
    useMutation: mockUseMutation
  };

  return (
    <MockConvexContext.Provider value={contextValue}>
      {children}
    </MockConvexContext.Provider>
  );
}

export function useQuery(api: any, args: any) {
  const context = useContext(MockConvexContext);
  if (!context) {
    throw new Error('useQuery must be used within MockConvexProvider');
  }
  return context.useQuery(api, args);
}

export function useMutation(api: any) {
  const context = useContext(MockConvexContext);
  if (!context) {
    throw new Error('useMutation must be used within MockConvexProvider');
  }
  return context.useMutation(api);
}
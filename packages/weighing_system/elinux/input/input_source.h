#ifndef INPUT_SOURCE_H
#define INPUT_SOURCE_H

#include "../common_types.h"
#include <functional>
#include <string>
#include <atomic>
#include <thread>

namespace weighing
{

	using AdcCallback = std::function<void(const AdcSample &)>;

	class InputSource
	{
	public:
		virtual ~InputSource() = default;

		virtual bool Initialize(const std::string &config_path) = 0;
		virtual bool Start() = 0;
		virtual void Stop() = 0;
		virtual bool IsRunning() const = 0;
		virtual InputMode GetMode() const = 0;
		virtual int GetChannelCount() const = 0;

		void SetAdcCallback(AdcCallback cb) { adc_callback_ = cb; }

	protected:
		AdcCallback adc_callback_;
	};

} // namespace weighing

#endif // INPUT_SOURCE_H